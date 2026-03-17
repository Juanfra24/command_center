import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/ip_score_indicator.dart';

Widget wrapInFluentApp(Widget child) {
  return FluentApp(
    home: ScaffoldPage(content: Center(child: child)),
  );
}

ProxyIpAddressEntity makeIp({
  double fraudScore = 0,
  DateTime? lastScoreCheck,
}) {
  final now = DateTime.now();
  return ProxyIpAddressEntity(
    id: 1,
    ipAddress: '1.2.3.4',
    hostname: '1.2.3.4',
    slotId: 1,
    isActive: true,
    countryCode: 'US',
    cityName: 'TestCity',
    ipTimezone: 'UTC',
    highCountryConfidence: true,
    asnName: 'TestASN',
    asnNumber: 12345,
    ipScore: 0,
    scoreLevel: IpScoreLevel.unknown,
    isVpn: false,
    isProxy: true,
    isDatacenter: false,
    isTor: false,
    fraudScore: fraudScore,
    assignedAt: now,
    lastVerification: now,
    lastScoreCheck: lastScoreCheck,
    totalDaysUsed: 0,
    timesAssigned: 1,
  );
}

void main() {
  group('IpScoreIndicator', () {
    testWidgets('shows "?" for unscored IP', (tester) async {
      final ip = makeIp(fraudScore: 0, lastScoreCheck: null);

      await tester.pumpWidget(
        wrapInFluentApp(IpScoreIndicator(ip: ip)),
      );
      await tester.pumpAndSettle();

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('shows numeric fraud score for scored IP', (tester) async {
      final ip = makeIp(fraudScore: 15, lastScoreCheck: DateTime.now());

      await tester.pumpWidget(
        wrapInFluentApp(IpScoreIndicator(ip: ip)),
      );
      await tester.pumpAndSettle();

      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('shows score rounded to integer', (tester) async {
      final ip = makeIp(fraudScore: 75.7, lastScoreCheck: DateTime.now());

      await tester.pumpWidget(
        wrapInFluentApp(IpScoreIndicator(ip: ip)),
      );
      await tester.pumpAndSettle();

      expect(find.text('76'), findsOneWidget);
    });
  });

  group('getScoreColor', () {
    test('returns green for fraud score <= 30', () {
      final color = getScoreColor(20);
      expect(color, equals(Colors.green));
    });

    test('returns yellow for fraud score <= 60', () {
      final color = getScoreColor(50);
      expect(color, equals(Colors.yellow));
    });

    test('returns orange for fraud score <= 80', () {
      final color = getScoreColor(70);
      expect(color, equals(Colors.orange));
    });

    test('returns red for fraud score > 80', () {
      final color = getScoreColor(90);
      expect(color, equals(Colors.red));
    });

    test('returns grey for unscored', () {
      final color = getScoreColor(0, hasBeenScored: false);
      // grey.toAccentColor() is used, which is an AccentColor
      expect(color, isA<AccentColor>());
    });
  });

  group('formatDate', () {
    test('formats date as d/m/yyyy', () {
      final result = formatDate(DateTime(2025, 3, 15));
      expect(result, equals('15/3/2025'));
    });

    test('formats single-digit day and month without padding', () {
      final result = formatDate(DateTime(2025, 1, 5));
      expect(result, equals('5/1/2025'));
    });
  });
}
