import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/config/services/automation/result_parser.dart';

/// AutomationService itself is tightly coupled to GetX DI (Get.find<PythonSetupService>,
/// Get.find<ProxyController>, etc.) and spawns OS processes, making it hard to unit test
/// in isolation. Instead, we test its two key dependencies:
/// - AutomationResult (data model + parsing)
/// - ResultParser (output parsing logic)
void main() {
  group('AutomationResult', () {
    test('fromJson parses success result', () {
      final result = AutomationResult.fromJson({
        'status': 'success',
        'message': 'Proxy validated',
        'expected_ip': '1.2.3.4',
        'actual_ip': '1.2.3.4',
      });

      expect(result.status, equals(AutomationStatus.success));
      expect(result.message, equals('Proxy validated'));
      expect(result.expectedIp, equals('1.2.3.4'));
      expect(result.actualIp, equals('1.2.3.4'));
      expect(result.isSuccess, isTrue);
    });

    test('fromJson parses account_created result', () {
      final result = AutomationResult.fromJson({
        'status': 'account_created',
        'message': 'Account created successfully',
        'data': {
          'email': 'test@example.com',
          'password': 'secretpass',
        },
      });

      expect(result.status, equals(AutomationStatus.accountCreated));
      expect(result.isAccountCreated, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.data?['email'], equals('test@example.com'));
    });

    test('fromJson parses proxy_validation_failed', () {
      final result = AutomationResult.fromJson({
        'status': 'proxy_validation_failed',
        'message': 'IP mismatch',
        'expected_ip': '1.2.3.4',
        'actual_ip': '5.6.7.8',
      });

      expect(result.status, equals(AutomationStatus.proxyValidationFailed));
      expect(result.proxyFailed, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('fromJson parses captcha_required', () {
      final result = AutomationResult.fromJson({
        'status': 'captcha_required',
        'message': 'Captcha detected',
      });

      expect(result.status, equals(AutomationStatus.captchaRequired));
      expect(result.needsCaptcha, isTrue);
    });

    test('fromJson handles unknown status', () {
      final result = AutomationResult.fromJson({
        'status': 'something_new',
        'message': 'Unexpected',
      });

      expect(result.status, equals(AutomationStatus.unknownError));
    });

    test('fromJson handles missing fields', () {
      final result = AutomationResult.fromJson({});

      expect(result.status, equals(AutomationStatus.unknownError));
      expect(result.message, equals('Unknown error'));
      expect(result.expectedIp, isNull);
      expect(result.actualIp, isNull);
      expect(result.data, isNull);
    });

    test('error factory creates error result', () {
      final result = AutomationResult.error('Something broke');

      expect(result.status, equals(AutomationStatus.unknownError));
      expect(result.message, equals('Something broke'));
      expect(result.isSuccess, isFalse);
    });
  });

  group('AutomationStatus', () {
    test('fromString maps all known values', () {
      expect(AutomationStatus.fromString('success'),
          equals(AutomationStatus.success));
      expect(AutomationStatus.fromString('proxy_validation_failed'),
          equals(AutomationStatus.proxyValidationFailed));
      expect(AutomationStatus.fromString('browser_error'),
          equals(AutomationStatus.browserError));
      expect(AutomationStatus.fromString('timeout'),
          equals(AutomationStatus.timeout));
      expect(AutomationStatus.fromString('captcha_required'),
          equals(AutomationStatus.captchaRequired));
      expect(AutomationStatus.fromString('account_created'),
          equals(AutomationStatus.accountCreated));
    });

    test('fromString returns unknownError for unrecognized value', () {
      expect(AutomationStatus.fromString('xyz'),
          equals(AutomationStatus.unknownError));
    });
  });

  group('ResultParser', () {
    group('extractJsonResult', () {
      test('extracts JSON after RESULT marker', () {
        const output = '''
Some log output
More logs
=== RESULT ===
{"status": "success", "message": "Done"}
''';
        final json = ResultParser.extractJsonResult(output);
        expect(json, isNotNull);
        expect(json!['status'], equals('success'));
        expect(json['message'], equals('Done'));
      });

      test('returns null when no RESULT marker present', () {
        const output = 'Some log output without any marker';
        final json = ResultParser.extractJsonResult(output);
        expect(json, isNull);
      });

      test('returns null for malformed JSON after marker', () {
        const output = '=== RESULT ===\nnot valid json';
        final json = ResultParser.extractJsonResult(output);
        expect(json, isNull);
      });

      test('handles nested JSON objects', () {
        const output = '''
=== RESULT ===
{"status": "account_created", "data": {"email": "a@b.com", "password": "p"}}
''';
        final json = ResultParser.extractJsonResult(output);
        expect(json, isNotNull);
        expect(json!['data']['email'], equals('a@b.com'));
      });

      test('handles extra text after JSON', () {
        const output = '''
=== RESULT ===
{"status": "success", "message": "OK"}
Some trailing output
''';
        final json = ResultParser.extractJsonResult(output);
        expect(json, isNotNull);
        expect(json!['status'], equals('success'));
      });
    });

    group('processScriptOutput', () {
      final logs = <String>[];
      void onLog(String msg) => logs.add(msg);

      setUp(() => logs.clear());

      test('returns parsed result from stdout JSON', () {
        final result = ResultParser.processScriptOutput(
          exitCode: 0,
          stdout:
              '=== RESULT ===\n{"status": "success", "message": "Validated"}',
          stderr: '',
          onLog: onLog,
        );

        expect(result.status, equals(AutomationStatus.success));
        expect(result.message, equals('Validated'));
      });

      test('returns error for ModuleNotFoundError in stderr', () {
        final result = ResultParser.processScriptOutput(
          exitCode: 1,
          stdout: '',
          stderr: 'ModuleNotFoundError: No module named "patchright"',
          onLog: onLog,
        );

        expect(result.status, equals(AutomationStatus.unknownError));
        expect(result.message, contains('Python dependency error'));
      });

      test('returns error for No module named in stderr', () {
        final result = ResultParser.processScriptOutput(
          exitCode: 1,
          stdout: '',
          stderr: 'ImportError: No module named requests',
          onLog: onLog,
        );

        expect(result.status, equals(AutomationStatus.unknownError));
        expect(result.message, contains('Python dependency error'));
      });

      test('prioritizes JSON result even with non-zero exit code', () {
        final result = ResultParser.processScriptOutput(
          exitCode: 1,
          stdout:
              '=== RESULT ===\n{"status": "captcha_required", "message": "Captcha detected"}',
          stderr: 'Some warning',
          onLog: onLog,
        );

        expect(result.status, equals(AutomationStatus.captchaRequired));
      });

      test('falls back to exit code error when no JSON', () {
        final result = ResultParser.processScriptOutput(
          exitCode: 1,
          stdout: 'Some output without JSON',
          stderr: 'Error details here',
          onLog: onLog,
        );

        expect(result.status, equals(AutomationStatus.unknownError));
        expect(result.message, contains('exit code 1'));
      });

      test('returns error for zero exit code without JSON', () {
        final result = ResultParser.processScriptOutput(
          exitCode: 0,
          stdout: 'No JSON here',
          stderr: '',
          onLog: onLog,
        );

        expect(result.status, equals(AutomationStatus.unknownError));
        expect(result.message, contains('Could not parse'));
      });
    });
  });
}
