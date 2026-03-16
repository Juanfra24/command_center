import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/core/helper/proxy_url_builder.dart';

void main() {
  group('ProxyUrlBuilder', () {
    test('builds SOCKS5 URL from components', () {
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'user123',
        password: 'pass456',
        ipAddress: '192.168.1.1',
        socksPort: 1080,
      );
      expect(url, 'socks5://user123:pass456@192.168.1.1:1080');
    });

    test('handles special characters in password', () {
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'user',
        password: 'p@ss:word',
        ipAddress: '10.0.0.1',
        socksPort: 9050,
      );
      expect(url, 'socks5://user:p@ss:word@10.0.0.1:9050');
    });

    test('builds URL from slot and IP entities', () {
      final url = ProxyUrlBuilder.buildSocks5Url(
        username: 'webshare_user',
        password: 'webshare_pass',
        ipAddress: '203.0.113.50',
        socksPort: 7777,
      );
      expect(url, 'socks5://webshare_user:webshare_pass@203.0.113.50:7777');
    });
  });
}
