/// Repository interface for app configuration
/// This is the domain layer - defines WHAT operations are available
/// Implementation details are in the data layer
abstract class ConfigRepository {
  /// Get a configuration value by key
  Future<String?> getValue(String key);

  /// Set a configuration value
  Future<void> setValue(String key, String value);

  /// Delete a configuration value
  Future<void> deleteValue(String key);

  /// Get all configuration as a map
  Future<Map<String, String>> getAllConfig();

  /// Clear all configuration
  Future<void> clearAll();

  /// Stream of configuration changes for a specific key
  Stream<String?> watchValue(String key);
}
