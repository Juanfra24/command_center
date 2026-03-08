import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/proxy/proxy_replacement_service.dart';
import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:get/get.dart';

class ProxyController extends GetxController {
  ProxyRepository? _proxyRepository;
  WebshareService? _webshareService;
  IpqsService? _ipqsService;
  ProxySyncService? _syncService;
  ProxyReplacementService? _replacementService;

  // Observable states
  var isLoading = true.obs;
  var isSyncing = false.obs;
  var isReplacing = false.obs;
  var proxySlots = <ProxySlotEntity>[].obs;
  var ipAddresses = <ProxyIpAddressEntity>[].obs;
  var selectedSlot = Rxn<ProxySlotEntity>();
  var selectedSlotIpHistory = <ProxyIpAddressEntity>[].obs;

  // Integration states
  var isWebshareConfigured = false.obs;
  var isIpqsConfigured = false.obs;
  var lastSyncError = Rxn<String>();

  // Subscription plan info
  var replacementsAvailable = Rxn<int>();
  var replacementsTotal = Rxn<int>();
  var replacementsUsed = Rxn<int>();

  // Filter states
  var showOnlyActive = true.obs;
  var sortByScore = false.obs;
  var searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _initRepository();
    _initWebshare();
    _initIpqs();
    _initSyncService();
    loadData();
  }

  void _initSyncService() {
    if (_proxyRepository != null && _webshareService != null) {
      _syncService = ProxySyncService(_proxyRepository!, _webshareService!);
    }
    if (_webshareService != null) {
      _replacementService = ProxyReplacementService(_webshareService!);
    }
  }

  void _initRepository() {
    try {
      _proxyRepository = Get.find<DatabaseService>().proxyRepository;
    } catch (e) {
      logger.e('DatabaseService not initialized yet: $e');
    }
  }

  void _initWebshare() {
    try {
      _webshareService = Get.find<WebshareService>();
      isWebshareConfigured.value = _webshareService!.isConfigured.value;

      // Listen for configuration changes
      ever(_webshareService!.isConfigured, (configured) {
        isWebshareConfigured.value = configured;
        if (configured) {
          syncWithWebshare();
          fetchPlanInfo();
        }
      });

      // Fetch plan info if already configured
      if (isWebshareConfigured.value) {
        fetchPlanInfo();
      }
    } catch (e) {
      logger.w('WebshareService not initialized yet');
    }
  }

  void _initIpqs() {
    try {
      _ipqsService = Get.find<IpqsService>();
      isIpqsConfigured.value = _ipqsService!.isConfigured.value;

      // Listen for configuration changes
      ever(_ipqsService!.isConfigured, (configured) {
        isIpqsConfigured.value = configured;
      });
    } catch (e) {
      logger.w('IpqsService not initialized yet');
    }
  }

  Future<void> loadData() async {
    isLoading.value = true;
    lastSyncError.value = null;
    try {
      await Future.wait([
        loadProxySlots(),
        loadIpAddresses(),
      ]);
    } catch (e) {
      logger.e('Error loading proxy data: $e');
      lastSyncError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// Sync proxy slots from Webshare API
  Future<void> syncWithWebshare() async {
    if (_syncService == null || !isWebshareConfigured.value) {
      lastSyncError.value =
          'Webshare not configured. Please add your API key in Settings.';
      return;
    }

    if (_proxyRepository == null) {
      lastSyncError.value = 'Database not initialized';
      return;
    }

    isSyncing.value = true;
    lastSyncError.value = null;

    try {
      await _syncService!.syncWithWebshare();
      // Reload data after sync
      await loadData();
    } catch (e) {
      logger.e('Error syncing with Webshare: $e');
      lastSyncError.value = 'Failed to sync: ${e.toString()}';
    } finally {
      isSyncing.value = false;
    }
  }

  /// Request IP rotation via Webshare API (legacy v2)
  Future<bool> rotateSlotIp(ProxySlotEntity slot) async {
    if (_replacementService == null ||
        !isWebshareConfigured.value ||
        slot.webshareId == null) {
      lastSyncError.value =
          'Cannot rotate IP: Webshare not configured or slot not linked';
      return false;
    }

    try {
      final success = await _replacementService!.rotateSlotIp(slot);
      if (success) {
        await syncWithWebshare();
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error rotating IP: $e');
      lastSyncError.value = 'Failed to rotate IP: ${e.toString()}';
      return false;
    }
  }

  /// Replace a proxy IP via the Webshare v3 Proxy Replacement API.
  Future<({bool success, String? error})> replaceProxyIp(
    ProxySlotEntity slot, {
    bool keepSameCountry = false,
  }) async {
    if (_replacementService == null || !isWebshareConfigured.value) {
      return (
        success: false,
        error: 'Webshare not configured. Please add your API key in Settings.'
      );
    }

    if (_proxyRepository == null) {
      return (success: false, error: 'Database not initialized');
    }

    final currentIp = getCurrentIpForSlot(slot);
    if (currentIp == null) {
      return (success: false, error: 'No active IP found for this slot');
    }

    isReplacing.value = true;
    lastSyncError.value = null;

    try {
      final result = await _replacementService!.replaceProxyIp(
        currentIp,
        keepSameCountry: keepSameCountry,
      );

      if (result.success) {
        // Sync to get the updated proxy data
        await syncWithWebshare();
        // Refresh plan info to update remaining replacements
        await fetchPlanInfo();
        return (success: true, error: null);
      } else {
        lastSyncError.value = result.error;
        return result;
      }
    } catch (e) {
      logger.e('Error replacing proxy: $e');
      final errorMsg = 'Failed to replace proxy: ${e.toString()}';
      lastSyncError.value = errorMsg;
      return (success: false, error: errorMsg);
    } finally {
      isReplacing.value = false;
    }
  }

  /// Fetch plan info from Webshare to get replacement quotas
  Future<void> fetchPlanInfo() async {
    if (_replacementService == null || !isWebshareConfigured.value) return;

    try {
      final plan = await _replacementService!.fetchPlanInfo();
      if (plan != null) {
        replacementsAvailable.value = plan.proxyReplacementsAvailable;
        replacementsTotal.value = plan.proxyReplacementsTotal;
        replacementsUsed.value = plan.proxyReplacementsUsed;
        logger.i(
            'Plan info: ${plan.proxyReplacementsAvailable}/${plan.proxyReplacementsTotal} replacements available');
      }
    } catch (e) {
      logger.w('Error fetching plan info: $e');
    }
  }

  /// Get details of low-score proxies for tooltip display
  List<String> getLowScoreSlotDetails() {
    final details = <String>[];
    for (final slot in proxySlots) {
      final ip = getCurrentIpForSlot(slot);
      if (ip != null && ip.ipScore > 0 && ip.ipScore < 50) {
        details.add(
            '${slot.slotName}: ${ip.ipAddress} (score: ${ip.ipScore.toStringAsFixed(0)})');
      }
    }
    return details;
  }

  /// Clear all proxy data from database (soft-delete)
  /// This is typically called when unlinking Webshare
  Future<void> clearAllProxyData() async {
    if (_proxyRepository == null) return;

    try {
      logger.i('Soft-deleting all proxy data from database...');
      final allSlots = await _proxyRepository!.getAllSlots();

      for (final slot in allSlots) {
        if (slot.id != null) {
          await _proxyRepository!.softDeleteSlot(slot.id!);
        }
      }

      // Clear in-memory state
      proxySlots.clear();
      ipAddresses.clear();
      selectedSlot.value = null;
      selectedSlotIpHistory.clear();

      logger.i('Successfully soft-deleted ${allSlots.length} proxy slots');
    } catch (e) {
      logger.e('Error clearing proxy data: $e');
      rethrow;
    }
  }

  Future<void> loadProxySlots() async {
    if (_proxyRepository == null) return;

    try {
      final slots = await _proxyRepository!.getAllSlots();
      proxySlots.value = slots;
      proxySlots.sort((a, b) => a.slotNumber.compareTo(b.slotNumber));
    } catch (e) {
      logger.e('Error loading proxy slots: $e');
    }
  }

  Future<void> loadIpAddresses() async {
    if (_proxyRepository == null) return;

    try {
      final ips = await _proxyRepository!.getAllIpAddresses();
      ipAddresses.value = ips;
    } catch (e) {
      logger.e('Error loading IP addresses: $e');
    }
  }

  // Get the current (active) IP address for a slot
  ProxyIpAddressEntity? getCurrentIpForSlot(ProxySlotEntity slot) {
    // First try by ID reference
    if (slot.currentIpAddressId != null) {
      final ip = ipAddresses.firstWhereOrNull(
        (ip) => ip.id == slot.currentIpAddressId && ip.isActive,
      );
      if (ip != null) return ip;
    }
    // Fallback: find active IP for this slot
    return ipAddresses.firstWhereOrNull(
      (ip) => ip.slotId == slot.id && ip.isActive,
    );
  }

  // Get IP history for a slot (all IPs including inactive, sorted by date)
  List<ProxyIpAddressEntity> getIpHistoryForSlot(int slotId) {
    return ipAddresses.where((ip) => ip.slotId == slotId).toList()
      ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
  }

  // Select a slot and load its details
  void selectSlot(ProxySlotEntity slot) {
    selectedSlot.value = slot;
    if (slot.id != null) {
      selectedSlotIpHistory.value = getIpHistoryForSlot(slot.id!);
    }
  }

  void clearSelection() {
    selectedSlot.value = null;
    selectedSlotIpHistory.clear();
  }

  // Filtered slots based on search and filters
  List<ProxySlotEntity> get filteredSlots {
    var result = proxySlots.toList();

    // Apply active filter
    if (showOnlyActive.value) {
      result = result.where((slot) => slot.isActive).toList();
    }

    // Apply search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result.where((slot) {
        final ip = getCurrentIpForSlot(slot);
        return slot.slotName.toLowerCase().contains(query) ||
            slot.slotNumber.toString().contains(query) ||
            (ip?.ipAddress.contains(query) ?? false) ||
            (ip?.cityName.toLowerCase().contains(query) ?? false) ||
            (ip?.countryCode.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Sort by score if enabled
    if (sortByScore.value) {
      result.sort((a, b) {
        final ipA = getCurrentIpForSlot(a);
        final ipB = getCurrentIpForSlot(b);
        return (ipB?.ipScore ?? 0).compareTo(ipA?.ipScore ?? 0);
      });
    }

    return result;
  }

  // Statistics
  int get totalSlots => proxySlots.length;
  int get activeSlots => proxySlots.where((s) => s.isActive).length;
  int get totalIpChanges =>
      proxySlots.fold(0, (sum, s) => sum + s.totalIpChanges);

  double get averageIpScore {
    final currentIps = proxySlots
        .map((s) => getCurrentIpForSlot(s))
        .where((ip) => ip != null && ip.ipScore > 0)
        .toList();
    if (currentIps.isEmpty) return 0;
    return currentIps.fold(0.0, (sum, ip) => sum + ip!.ipScore) /
        currentIps.length;
  }

  int get lowScoreCount {
    return proxySlots.where((slot) {
      final ip = getCurrentIpForSlot(slot);
      return ip != null && ip.ipScore > 0 && ip.ipScore < 50;
    }).length;
  }

  // Add a new proxy slot manually
  Future<void> addProxySlot(ProxySlotEntity slot) async {
    if (_proxyRepository == null) return;

    try {
      await _proxyRepository!.insertSlot(slot);
      await loadProxySlots();
    } catch (e) {
      logger.e('Error adding proxy slot: $e');
      rethrow;
    }
  }

  // Update a proxy slot
  Future<void> updateProxySlot(ProxySlotEntity slot) async {
    if (_proxyRepository == null) return;

    try {
      await _proxyRepository!.updateSlot(slot);
      await loadProxySlots();
    } catch (e) {
      logger.e('Error updating proxy slot: $e');
      rethrow;
    }
  }

  /// Update just the slot name
  Future<bool> updateSlotName(ProxySlotEntity slot, String newName) async {
    if (_proxyRepository == null) return false;

    try {
      await _proxyRepository!.updateSlot(slot.copyWith(slotName: newName));
      await loadProxySlots();

      // Update selectedSlot if it was the one being edited
      if (selectedSlot.value?.id == slot.id) {
        selectedSlot.value = slot.copyWith(slotName: newName);
      }

      return true;
    } catch (e) {
      logger.e('Error updating slot name: $e');
      return false;
    }
  }

  // Update IP score
  Future<void> updateIpScore(ProxyIpAddressEntity ip, double newScore) async {
    if (_proxyRepository == null) return;

    try {
      await _proxyRepository!.updateIpAddress(
        ip.copyWith(
          ipScore: newScore,
          lastScoreCheck: DateTime.now(),
        ),
      );
      await loadIpAddresses();
    } catch (e) {
      logger.e('Error updating IP score: $e');
      rethrow;
    }
  }
}
