import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';

import 'package:command_center/core/resource/result.dart';

void main() {
  late IpqsService service;

  setUp(() {
    Get.testMode = true;
    service = IpqsService();
  });

  tearDown(() {
    Get.reset();
  });

  group('IpqsService - observable states', () {
    test('initial states are correct', () {
      expect(service.apiKey.value, isNull);
      expect(service.isConfigured.value, isFalse);
      expect(service.isLoading.value, isFalse);
      expect(service.lastError.value, isNull);
    });
  });

  group('IpqsService - saveApiKey', () {
    test('returns failure when config repository not initialized', () async {
      final result = await service.saveApiKey('test-key');
      expect(result, isA<Failure<void>>());
      expect(
        (result as Failure).message,
        equals('Config repository not initialized'),
      );
    });
  });

  group('IpqsService - clearApiKey', () {
    test('returns failure when config repository not initialized', () async {
      final result = await service.clearApiKey();
      expect(result, isA<Failure<void>>());
      expect(
        (result as Failure).message,
        equals('Config repository not initialized'),
      );
    });
  });

  group('IpqsService - scoreIp', () {
    test('returns error when API key not configured', () async {
      final result = await service.scoreIp('8.8.8.8');
      expect(result.success, isFalse);
      expect(result.error, contains('not configured'));
    });
  });

  group('IpqsResult', () {
    test('fromJson parses success response', () {
      final result = IpqsResult.fromJson({
        'success': true,
        'fraud_score': 25.0,
        'proxy': true,
        'vpn': false,
        'tor': false,
        'connection_type': 'Datacenter',
        'ISP': 'TestISP',
        'country_code': 'US',
        'city': 'TestCity',
      });

      expect(result.success, isTrue);
      expect(result.fraudScore, equals(25.0));
      expect(result.isProxy, isTrue);
      expect(result.isVpn, isFalse);
      expect(result.isDatacenter, isTrue);
      expect(result.countryCode, equals('US'));
    });

    test('fromJson handles missing fields gracefully', () {
      final result = IpqsResult.fromJson({});

      expect(result.success, isFalse);
      expect(result.fraudScore, equals(0));
      expect(result.isProxy, isFalse);
    });

    test('error factory creates error result', () {
      final result = IpqsResult.error('Something broke');

      expect(result.success, isFalse);
      expect(result.error, equals('Something broke'));
    });

    test('normalizedScore inverts fraud score', () {
      final result = IpqsResult(fraudScore: 30);
      expect(result.normalizedScore, equals(70));
    });

    test('qualityRating returns correct ratings', () {
      expect(IpqsResult(fraudScore: 10).qualityRating, equals('Excellent'));
      expect(IpqsResult(fraudScore: 30).qualityRating, equals('Good'));
      expect(IpqsResult(fraudScore: 60).qualityRating, equals('Fair'));
      expect(IpqsResult(fraudScore: 80).qualityRating, equals('Poor'));
      expect(IpqsResult(fraudScore: 90).qualityRating, equals('Very Poor'));
    });
  });
}
