import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/domain/entities/proxy_ip_address.dart';
import 'package:command_center/feature/proxy/views/components/ip_history_list.dart';

/// Wraps a widget in a FluentApp for testing
Widget wrapInFluentApp(Widget child) {
  return FluentApp(
    home: ScaffoldPage(content: SingleChildScrollView(child: child)),
  );
}

ProxyIpAddressEntity makeIp({
  int? id,
  String ipAddress = '1.2.3.4',
  int slotId = 1,
  bool isActive = true,
  double ipScore = 0,
  String countryCode = 'US',
  String cityName = 'TestCity',
  DateTime? assignedAt,
  DateTime? lastScoreCheck,
}) {
  final now = DateTime.now();
  return ProxyIpAddressEntity(
    id: id,
    ipAddress: ipAddress,
    hostname: ipAddress,
    slotId: slotId,
    isActive: isActive,
    countryCode: countryCode,
    cityName: cityName,
    ipTimezone: 'UTC',
    highCountryConfidence: true,
    asnName: 'TestASN',
    asnNumber: 12345,
    ipScore: ipScore,
    scoreLevel: ProxyIpAddressEntity.getScoreLevel(ipScore),
    isVpn: false,
    isProxy: true,
    isDatacenter: false,
    isTor: false,
    fraudScore: 0,
    assignedAt: assignedAt ?? now,
    lastVerification: now,
    lastScoreCheck: lastScoreCheck,
    totalDaysUsed: 0,
    timesAssigned: 1,
  );
}

void main() {
  group('IpHistoryList', () {
    testWidgets('renders empty state message when no history', (tester) async {
      await tester.pumpWidget(
        wrapInFluentApp(const IpHistoryList(history: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No IP history yet'), findsOneWidget);
    });

    testWidgets('renders IP addresses from history', (tester) async {
      final history = [
        makeIp(ipAddress: '10.0.0.1', cityName: 'New York', countryCode: 'US'),
        makeIp(
          ipAddress: '10.0.0.2',
          cityName: 'London',
          countryCode: 'GB',
          isActive: false,
        ),
      ];

      await tester.pumpWidget(
        wrapInFluentApp(IpHistoryList(history: history)),
      );
      await tester.pumpAndSettle();

      expect(find.text('10.0.0.1'), findsOneWidget);
      expect(find.text('10.0.0.2'), findsOneWidget);
      expect(find.text('New York, US'), findsOneWidget);
      expect(find.text('London, GB'), findsOneWidget);
    });

    testWidgets('shows "?" for unscored IPs', (tester) async {
      final history = [makeIp(ipScore: 0, lastScoreCheck: null)];

      await tester.pumpWidget(
        wrapInFluentApp(IpHistoryList(history: history)),
      );
      await tester.pumpAndSettle();

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('shows numeric score for scored IPs', (tester) async {
      final history = [
        makeIp(ipScore: 85, lastScoreCheck: DateTime.now()),
      ];

      await tester.pumpWidget(
        wrapInFluentApp(IpHistoryList(history: history)),
      );
      await tester.pumpAndSettle();

      expect(find.text('85'), findsOneWidget);
    });

    testWidgets('truncates list at 10 entries and shows count', (tester) async {
      final history = List.generate(
        15,
        (i) => makeIp(
          id: i,
          ipAddress: '10.0.0.${i + 1}',
          assignedAt: DateTime(2025, 1, 1).add(Duration(days: i)),
        ),
      );

      await tester.pumpWidget(
        wrapInFluentApp(IpHistoryList(history: history)),
      );
      await tester.pumpAndSettle();

      // Should show truncation message
      expect(find.text('Showing 10 of 15 entries'), findsOneWidget);
      // First 10 should be visible, 11th-15th should not
      expect(find.text('10.0.0.1'), findsOneWidget);
      expect(find.text('10.0.0.10'), findsOneWidget);
      expect(find.text('10.0.0.11'), findsNothing);
    });

    testWidgets('does not show truncation for 10 or fewer entries',
        (tester) async {
      final history = List.generate(
        5,
        (i) => makeIp(id: i, ipAddress: '10.0.0.${i + 1}'),
      );

      await tester.pumpWidget(
        wrapInFluentApp(IpHistoryList(history: history)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Showing'), findsNothing);
    });
  });
}
