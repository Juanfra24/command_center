import 'package:command_center/domain/entities/proxy_slot.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';

/// Repository interface for proxy management
/// This is the domain layer - defines WHAT operations are available
abstract class ProxyRepository {
  // ===== Proxy Slots =====

  /// Get all proxy slots (excludes soft-deleted by default)
  Future<List<ProxySlotEntity>> getAllSlots();

  /// Get all proxy slots including soft-deleted ones
  Future<List<ProxySlotEntity>> getAllSlotsIncludingDeleted();

  /// Get a single slot by ID
  Future<ProxySlotEntity?> getSlotById(int id);

  /// Get a slot by Webshare ID (includes soft-deleted slots for recovery)
  Future<ProxySlotEntity?> getSlotByWebshareId(String webshareId);

  /// Get a slot by slot number
  Future<ProxySlotEntity?> getSlotByNumber(int slotNumber);

  /// Insert a new slot, returns the generated ID
  Future<int> insertSlot(ProxySlotEntity slot);

  /// Update an existing slot
  Future<void> updateSlot(ProxySlotEntity slot);

  /// Soft-delete a slot by ID (marks as deleted, preserves data)
  Future<void> softDeleteSlot(int id);

  /// Recover a soft-deleted slot (marks as not deleted)
  Future<void> recoverSlot(int id);

  /// Hard delete a slot by ID (permanently removes)
  Future<void> deleteSlot(int id);

  /// Watch all slots (stream, excludes soft-deleted)
  Stream<List<ProxySlotEntity>> watchAllSlots();

  // ===== IP Addresses =====

  /// Get all IP addresses
  Future<List<ProxyIpAddressEntity>> getAllIpAddresses();

  /// Get all IP addresses for a specific slot
  Future<List<ProxyIpAddressEntity>> getIpAddressesForSlot(int slotId);

  /// Get the active IP address for a slot
  Future<ProxyIpAddressEntity?> getActiveIpForSlot(int slotId);

  /// Get an IP address by ID
  Future<ProxyIpAddressEntity?> getIpAddressById(int id);

  /// Insert a new IP address, returns the generated ID
  Future<int> insertIpAddress(ProxyIpAddressEntity ip);

  /// Update an IP address
  Future<void> updateIpAddress(ProxyIpAddressEntity ip);

  /// Mark an IP as inactive (for history tracking)
  Future<void> deactivateIp(int id);

  /// Delete an IP address by ID
  Future<void> deleteIpAddress(int id);

  /// Watch IP addresses for a slot
  Stream<List<ProxyIpAddressEntity>> watchIpAddressesForSlot(int slotId);

  // ===== Sync Operations =====

  /// Upsert a slot (insert or update based on webshareId or slotNumber)
  /// Returns the slot ID
  Future<int> upsertSlot(ProxySlotEntity slot);
}
