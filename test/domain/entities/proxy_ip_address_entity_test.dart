import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProxyIpAddressEntity', () {
    test('empty factory includes new IPQS fields as null/false', () {
      final entity = ProxyIpAddressEntity.empty();
      expect(entity.isCrawler, isNull);
      expect(entity.connectionType, isNull);
      expect(entity.isp, isNull);
      expect(entity.organization, isNull);
      expect(entity.region, isNull);
      expect(entity.recentAbuse, isNull);
    });

    test('copyWith updates new fields', () {
      final entity = ProxyIpAddressEntity.empty();
      final updated = entity.copyWith(
        isCrawler: true,
        connectionType: 'datacenter',
        isp: 'AT&T',
        organization: 'AT&T Corp',
        region: 'New York',
        recentAbuse: false,
      );
      expect(updated.isCrawler, true);
      expect(updated.connectionType, 'datacenter');
      expect(updated.isp, 'AT&T');
      expect(updated.organization, 'AT&T Corp');
      expect(updated.region, 'New York');
      expect(updated.recentAbuse, false);
    });

    test('getFraudScoreLabel returns correct labels', () {
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(10),
        'Excellent',
      );
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(45),
        'Fair',
      );
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(70),
        'Poor',
      );
      expect(
        ProxyIpAddressEntity.getFraudScoreLabel(90),
        'Bad',
      );
    });
  });
}
