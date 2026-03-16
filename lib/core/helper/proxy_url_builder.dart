/// Constructs SOCKS5 proxy URLs from individual components.
/// Single code path used by StatusController (launch) and WatchdogHandlers (ban rotation).
class ProxyUrlBuilder {
  ProxyUrlBuilder._();

  /// Build a SOCKS5 proxy URL: socks5://user:pass@host:port
  static String buildSocks5Url({
    required String username,
    required String password,
    required String ipAddress,
    required int socksPort,
  }) {
    return 'socks5://$username:$password@$ipAddress:$socksPort';
  }
}
