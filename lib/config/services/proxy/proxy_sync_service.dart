import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/data/database/app_database.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';

/// Handles synchronization of proxy slots between Webshare API and local database.
class ProxySyncService {
  final ProxyRepository _proxyRepository;
  final WebshareService _webshareService;
  final AppDatabase? _database;

  ProxySyncService(this._proxyRepository, this._webshareService,
      [this._database]);

  /// Sync proxy slots from Webshare API.
  /// Uses webshareId as the stable identifier:
  /// - If a slot with the same webshareId exists (even soft-deleted), recover/update it
  /// - If a slot doesn't exist, create a new one
  /// - If a DB slot's webshareId is not in the API response, soft-delete it
  Future<void> syncWithWebshare() async {
    final webshareProxies = await _webshareService.getProxyList();

    if (_database != null) {
      await _database.transaction(() => _performSync(webshareProxies));
    } else {
      await _performSync(webshareProxies);
    }

    logger.i(
        'Successfully synced ${webshareProxies.length} proxies from Webshare');
  }

  Future<void> _performSync(List<WebshareProxySlot> webshareProxies) async {
    // Get ALL existing slots from DB, including soft-deleted ones
    final allExistingSlots =
        await _proxyRepository.getAllSlotsIncludingDeleted();

    // Track which webshareIds we see from the API
    final apiWebshareIds = <String>{};

    for (final webProxy in webshareProxies) {
      apiWebshareIds.add(webProxy.id);

      // Check if this slot already exists by Webshare ID (including deleted)
      final existingSlot = allExistingSlots.firstWhereOrNull(
        (s) => s.webshareId == webProxy.id,
      );

      if (existingSlot != null) {
        if (existingSlot.isDeleted) {
          // Recover soft-deleted slot
          logger.i(
              'Recovering soft-deleted slot #${webProxy.slotNumber} (webshareId: ${webProxy.id})');
          await _proxyRepository.recoverSlot(existingSlot.id!);
        }
        // Update existing slot (whether it was deleted or not)
        await _updateExistingSlot(existingSlot, webProxy);
      } else {
        // New slot - create it
        await _createNewSlot(webProxy);
      }
    }

    // Soft-delete any DB slots whose webshareId is NOT in the API response
    // Skip manually added slots (no webshareId) — they aren't API-managed
    for (final existingSlot in allExistingSlots) {
      if (existingSlot.webshareId != null &&
          existingSlot.webshareId!.isNotEmpty &&
          !apiWebshareIds.contains(existingSlot.webshareId) &&
          !existingSlot.isDeleted) {
        logger.i(
            'Soft-deleting slot #${existingSlot.slotNumber} (webshareId: ${existingSlot.webshareId}) - not found in API');
        await _proxyRepository.softDeleteSlot(existingSlot.id!);
      }
    }
  }

  Future<void> _createNewSlot(WebshareProxySlot webProxy) async {
    final now = DateTime.now();

    logger.i('Creating new slot #${webProxy.slotNumber}');
    logger.i('  Webshare ID: ${webProxy.id}');
    logger.i('  Proxy Address: ${webProxy.proxyAddress}');
    logger.i('  Port: ${webProxy.port}');

    // Create the slot
    final slotId = await _proxyRepository.insertSlot(
      ProxySlotEntity(
        webshareId: webProxy.id,
        slotName: 'Slot ${webProxy.slotNumber}',
        slotNumber: webProxy.slotNumber,
        currentIpAddressId: null,
        username: webProxy.username,
        password: webProxy.password,
        port: webProxy.port,
        createdAt: webProxy.createdAt,
        lastUpdated: now,
        totalIpChanges: 0,
        isActive: webProxy.valid,
      ),
    );

    logger.i('  Slot created with ID: $slotId');

    // Create the IP address record
    final ipId = await _proxyRepository.insertIpAddress(
      ProxyIpAddressEntity(
        ipAddress: webProxy.proxyAddress,
        hostname: webProxy.proxyAddress,
        slotId: slotId,
        isActive: true,
        countryCode: webProxy.countryCode,
        cityName: webProxy.cityName,
        ipTimezone: 'UTC',
        highCountryConfidence: true,
        asnName: webProxy.asnName ?? '',
        asnNumber: webProxy.asnNumber ?? 0,
        ipScore: 0,
        scoreLevel: IpScoreLevel.unknown,
        isVpn: false,
        isProxy: true,
        isDatacenter: true,
        isTor: false,
        fraudScore: 0,
        recentAbuse: false,
        assignedAt: now,
        removedAt: null,
        lastVerification: webProxy.lastVerification ?? now,
        lastScoreCheck: null,
        totalDaysUsed: 0,
        timesAssigned: 1,
      ),
    );

    // Update slot with IP reference
    final slot = await _proxyRepository.getSlotById(slotId);
    if (slot != null) {
      await _proxyRepository
          .updateSlot(slot.copyWith(currentIpAddressId: ipId));
    }
  }

  Future<void> _updateExistingSlot(
    ProxySlotEntity existingSlot,
    WebshareProxySlot webProxy,
  ) async {
    final now = DateTime.now();
    final currentIp =
        await _proxyRepository.getActiveIpForSlot(existingSlot.id!);

    // Check if critical fields have changed
    final usernameChanged = existingSlot.username != webProxy.username;
    final ipChanged = currentIp?.ipAddress != webProxy.proxyAddress;

    if (usernameChanged) {
      logger.i('Credentials updated for slot #${webProxy.slotNumber}');
    }

    // Always update slot with latest data from Webshare
    await _proxyRepository.updateSlot(
      existingSlot.copyWith(
        webshareId: webProxy.id,
        username: webProxy.username,
        password: webProxy.password,
        port: webProxy.port,
        isActive: webProxy.valid,
        isDeleted: false,
        deletedAt: null,
        lastUpdated: now,
      ),
    );

    // Handle IP change if needed
    if (ipChanged) {
      logger.i('IP changed for slot #${webProxy.slotNumber}');
      logger.i('  Old: ${currentIp?.ipAddress}');
      logger.i('  New: ${webProxy.proxyAddress}');

      // Mark old IP as inactive
      if (currentIp != null && currentIp.id != null) {
        await _proxyRepository.deactivateIp(currentIp.id!);
      }

      // Create new IP record
      final newIpId = await _proxyRepository.insertIpAddress(
        ProxyIpAddressEntity(
          ipAddress: webProxy.proxyAddress,
          hostname: webProxy.proxyAddress,
          slotId: existingSlot.id!,
          isActive: true,
          countryCode: webProxy.countryCode,
          cityName: webProxy.cityName,
          ipTimezone: 'UTC',
          highCountryConfidence: true,
          asnName: webProxy.asnName ?? '',
          asnNumber: webProxy.asnNumber ?? 0,
          ipScore: 0,
          scoreLevel: IpScoreLevel.unknown,
          isVpn: false,
          isProxy: true,
          isDatacenter: true,
          isTor: false,
          fraudScore: 0,
          recentAbuse: false,
          assignedAt: now,
          removedAt: null,
          lastVerification: webProxy.lastVerification ?? now,
          lastScoreCheck: null,
          totalDaysUsed: 0,
          timesAssigned: 1,
        ),
      );

      // Update slot with new IP reference and increment change count
      await _proxyRepository.updateSlot(
        existingSlot.copyWith(
          currentIpAddressId: newIpId,
          totalIpChanges: existingSlot.totalIpChanges + 1,
        ),
      );
    }
  }
}

// Extension for firstWhereOrNull on regular List (not GetX RxList)
extension _ListFirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
