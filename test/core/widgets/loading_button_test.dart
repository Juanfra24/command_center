import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/core/widgets/loading_button.dart';

void main() {
  group('LoadingButton', () {
    testWidgets('shows label in idle state', (tester) async {
      await tester.pumpWidget(
        FluentApp(
          home: LoadingButton(
            label: 'Score IP',
            onPressed: () async {},
          ),
        ),
      );
      expect(find.text('Score IP'), findsOneWidget);
    });

    testWidgets('shows loading text when pressed', (tester) async {
      await tester.pumpWidget(
        FluentApp(
          home: LoadingButton(
            label: 'Score IP',
            loadingLabel: 'Scoring...',
            onPressed: () async {
              await Future.delayed(const Duration(seconds: 2));
            },
          ),
        ),
      );

      await tester.tap(find.text('Score IP'));
      await tester.pump();
      expect(find.text('Scoring...'), findsOneWidget);

      // Advance past loading + success states to avoid pending timer warnings
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
