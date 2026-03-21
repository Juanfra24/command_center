import 'package:command_center/config/services/proxy/proxy_sync_service.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database_service.dart';
import 'package:command_center/domain/entities/character.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/feature/proxy/data/linked_characters_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Presentation controller for proxy slot management.
/// Scoring UI state lives in [ProxyScoringController].
/// Replacement UI state lives in [ProxyReplacementController].
class ProxyController extends GetxController {
  final List<Worker> _workers = [];

  ProxyRepository? _proxyRepository;
  WebshareService? _webshareService;
  ProxySyncService? _syncService;
  LinkedCharactersLoader _linkedCharactersLoader = LinkedCharactersLoader(null);

  // Observable states
  var isLoading = true.obs;
  var isSyncing = false.obs;
  var proxySlots = <ProxySlotEntity>[].obs;
  var ipAddresses = <ProxyIpAddressEntity>[].obs;
  var selectedSlot = Rxn<ProxySlotEntity>();
  var selectedSlotIpHistory = <ProxyIpAddressEntity>[].obs;

  /// Characters linked to the currently selected slot.
  RxList<CharacterEntity> get linkedCharacters =>
      _linkedCharactersLoader.linkedCharacters;

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
      final db = Get.find<DatabaseService>();
      _proxyRepository = db.proxyRepository;
      _linkedCharactersLoader = LinkedCharactersLoader(db.accountRepository);
    } catch (e) {
      logger.e('DatabaseService not initialized yet: $e');
      _linkedCharactersLoader = LinkedCharactersLoader(null);
    }
  }

  void _initWebshare() {
    try {
      _webshareService = Get.find<WebshareService>();
      isWebshareConfigured.value = _webshareService!.isConfigured.value;

      // Listen for configuration changes
      _workers.add(ever(_webshareService!.isConfigured, (configured) {
        isWebshareConfigured.value = configured;
        if (configured) {
          syncWithWebshare();
        }
      }));
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
      // Refresh selected slot's IP history if a slot is selected
      if (selectedSlot.value?.id != null) {
        selectedSlotIpHistory.value =
            getIpHistoryForSlot(selectedSlot.value!.id!);
      }
    } catch (e) {
      logger.e('Error loading IP addresses: $e');
    }
  }

  void _rebuildIpLookup() {
    _ipById.clear();
    _activeIpBySlotId.clear();
    for (final ip in ipAddresses) {
      if (ip.id != null) _ipById[ip.id!] = ip;
      if (ip.isActive) _activeIpBySlotId.putIfAbsent(ip.slotId, () => ip);
    }
  }

  @visibleForTesting
  void rebuildIpLookup() => _rebuildIpLookup();

  // --- Sync ---

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
  Future<void> clearAllProxyData() async {
    if (_proxyRepository == null) return;
    try {
      await _proxyRepository!.softDeleteAllSlots();
      proxySlots.clear();
      ipAddresses.clear();
      selectedSlot.value = null;
      selectedSlotIpHistory.clear();
    } catch (e) {
      logger.e('Error clearing proxy data: $e');
      rethrow;
    }
  }

  void selectSlot(ProxySlotEntity slot) {
    selectedSlot.value = slot;
    if (slot.id != null) {
      selectedSlotIpHistory.value = getIpHistoryForSlot(slot.id!);
      _linkedCharactersLoader.loadForSlot(slot.id!);
    }
  }

  void clearSelection() {
    selectedSlot.value = null;
    selectedSlotIpHistory.clear();
    _linkedCharactersLoader.clear();
  }

  ProxyIpAddressEntity? getCurrentIpForSlot(ProxySlotEntity slot) {
    if (slot.currentIpAddressId != null) {
      final ip = _ipById[slot.currentIpAddressId!];
      if (ip != null && ip.isActive) return ip;
    }
    return _activeIpBySlotId[slot.id];
  }

  List<ProxyIpAddressEntity> getIpHistoryForSlot(int slotId) {
    return ipAddresses.where((ip) => ip.slotId == slotId).toList()
      ..sort((a, b) => b.assignedAt.compareTo(a.assignedAt));
  }

  // --- Filtering ---

  /// Filtered slots based on search and active filter.
  List<ProxySlotEntity> getFilteredSlots({bool sortByScore = false}) {
    Iterable<ProxySlotEntity> result = proxySlots;
    if (showOnlyActive.value) {
      result = result.where((slot) => slot.isActive);
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
      });
    }

    final list = result.toList();
    if (sortByScore) {
      list.sort((a, b) {
        final ipA = getCurrentIpForSlot(a);
        final ipB = getCurrentIpForSlot(b);
        final scoreA = ipA?.fraudScore ?? 100;
        final scoreB = ipB?.fraudScore ?? 100;
        return scoreA.compareTo(scoreB);
      });
    }

    return list;
  }

  int get totalSlots => proxySlots.length;
  int get activeSlots => proxySlots.where((s) => s.isActive).length;
  int get totalIpChanges =>
      proxySlots.fold(0, (sum, s) => sum + s.totalIpChanges);

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

  Future<bool> updateSlotName(ProxySlotEntity slot, String newName) async {
    if (_proxyRepository == null) return false;
    try {
      await _proxyRepository!.updateSlot(slot.copyWith(slotName: newName));
      await loadProxySlots();
      if (selectedSlot.value?.id == slot.id) {
        selectedSlot.value =
            proxySlots.firstWhereOrNull((s) => s.id == slot.id);
      }
      return true;
    } catch (e) {
      logger.e('Error updating slot name: $e');
      return false;
    }
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
