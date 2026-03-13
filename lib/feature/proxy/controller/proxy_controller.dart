import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Presentation controller for proxy slot management.
/// Handles selection, filtering, search, sync, and CRUD.
///
/// Scoring UI state lives in [ProxyScoringController].
/// Replacement UI state lives in [ProxyReplacementController].
class ProxyController extends GetxController {
  ProxyRepository? _proxyRepository;
  WebshareService? _webshareService;
  ProxySyncService? _syncService;

  // Observable states
  var isLoading = true.obs;
  var isSyncing = false.obs;
  var proxySlots = <ProxySlotEntity>[].obs;
  var ipAddresses = <ProxyIpAddressEntity>[].obs;
  var selectedSlot = Rxn<ProxySlotEntity>();
  var selectedSlotIpHistory = <ProxyIpAddressEntity>[].obs;

  // Integration states
  var isWebshareConfigured = false.obs;
  var lastSyncError = Rxn<String>();

  // Filter states
  var showOnlyActive = true.obs;
  var searchQuery = ''.obs;

  // IP lookup caches — rebuilt after every loadIpAddresses()
  final _ipById = <int, ProxyIpAddressEntity>{};
  final _activeIpBySlotId = <int, ProxyIpAddressEntity>{};

  @override
  void onInit() {
    super.onInit();
    _initRepository();
    _initWebshare();
    _initSyncService();
    loadData();
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
        }
      });
    } catch (e) {
      logger.w('WebshareService not initialized yet');
    }
  }

  void _initSyncService() {
    try {
      _syncService = Get.find<ProxySyncService>();
    } catch (e) {
      logger.w('ProxySyncService not available yet: $e');
    }
  }

  // --- Data loading ---

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
      _rebuildIpLookup();
    } catch (e) {
      logger.e('Error loading IP addresses: $e');
    }
  }

  void _rebuildIpLookup() {
    _ipById.clear();
    _activeIpBySlotId.clear();
    for (final ip in ipAddresses) {
      if (ip.id != null) _ipById[ip.id!] = ip;
      if (ip.isActive) {
        // First active IP per slot wins (matches firstWhereOrNull behavior)
        _activeIpBySlotId.putIfAbsent(ip.slotId, () => ip);
      }
    }
  }

  /// Rebuilds IP lookup caches from current [ipAddresses].
  /// Exposed for tests that populate [ipAddresses] directly.
  @visibleForTesting
  void rebuildIpLookup() => _rebuildIpLookup();

  // --- Sync ---

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
      final previousSelectedId = selectedSlot.value?.id;
      await _syncService!.syncWithWebshare();
      await loadData();
      // Re-select the previously selected slot by ID
      if (previousSelectedId != null) {
        final restored =
            proxySlots.firstWhereOrNull((s) => s.id == previousSelectedId);
        if (restored != null) {
          selectSlot(restored);
        }
      }
    } catch (e) {
      logger.e('Error syncing with Webshare: $e');
      lastSyncError.value = 'Failed to sync: ${e.toString()}';
    } finally {
      isSyncing.value = false;
    }
  }

  /// Clear all proxy data from database (soft-delete).
  /// Typically called when unlinking Webshare.
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

  // --- Selection ---

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

  // --- IP lookups ---

  /// Get the current (active) IP address for a slot
  ProxyIpAddressEntity? getCurrentIpForSlot(ProxySlotEntity slot) {
    // Fast path: look up by currentIpAddressId
    if (slot.currentIpAddressId != null) {
      final ip = _ipById[slot.currentIpAddressId!];
      if (ip != null && ip.isActive) return ip;
    }
    // Fallback: first active IP for this slot
    return _activeIpBySlotId[slot.id];
  }

  /// Get IP history for a slot (all IPs including inactive, sorted by date)
  List<ProxyIpAddressEntity> getIpHistoryForSlot(int slotId) {
    return ipAddresses.where((ip) => ip.slotId == slotId).toList()
      ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
  }

  // --- Filtering ---

  /// Filtered slots based on search and active filter.
  /// Score-based sorting is driven by [ProxyScoringController.sortByScore].
  List<ProxySlotEntity> getFilteredSlots({bool sortByScore = false}) {
    var result = proxySlots.toList();

    if (showOnlyActive.value) {
      result = result.where((slot) => slot.isActive).toList();
    }

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

    if (sortByScore) {
      result.sort((a, b) {
        final ipA = getCurrentIpForSlot(a);
        final ipB = getCurrentIpForSlot(b);
        return (ipB?.ipScore ?? 0).compareTo(ipA?.ipScore ?? 0);
      });
    }

    return result;
  }

  // --- Statistics ---

  int get totalSlots => proxySlots.length;
  int get activeSlots => proxySlots.where((s) => s.isActive).length;
  int get totalIpChanges =>
      proxySlots.fold(0, (sum, s) => sum + s.totalIpChanges);

  // --- CRUD ---

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

      if (selectedSlot.value?.id == slot.id) {
        selectedSlot.value = slot.copyWith(slotName: newName);
      }

      return true;
    } catch (e) {
      logger.e('Error updating slot name: $e');
      return false;
    }
  }
}
