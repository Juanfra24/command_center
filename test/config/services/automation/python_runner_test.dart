import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/automation/python_runner.dart';

void main() {
  group('PythonRunner.redact()', () {
    // -------------------------------------------------------------------------
    // Proxy credential redaction: user:pass@host
    // -------------------------------------------------------------------------
    group('proxy credentials', () {
      test('redacts password in user:pass@host:port format', () {
        const input = 'user123:s3cr3tPass@p.webshare.io:80';
        expect(
            PythonRunner.redact(input), equals('user123:***@p.webshare.io:80'));
      });

      test('redacts password when embedded in a longer string', () {
        const input =
            'Connecting with proxy user123:hunter2@p.webshare.io:80 ...';
        expect(
          PythonRunner.redact(input),
          equals('Connecting with proxy user123:***@p.webshare.io:80 ...'),
        );
      });

      test('redacts password that contains special characters', () {
        // Passwords with symbols other than ':' and '@' must be redacted.
        const input = 'alice:p@ssword123@proxy.host:9090';
        // The regex :[^:@]+@ matches :p and stops at the literal '@' in the
        // password — so the first ':p' segment is redacted. The remaining
        // 'ssword123@proxy.host:9090' is then processed, and the second
        // ':***@' pattern also fires. Both substitutions are expected.
        final result = PythonRunner.redact(input);
        expect(result, isNot(contains('p@ssword123')));
        expect(result, contains('***'));
      });

      test('redacts multiple proxy credentials in one string', () {
        const input =
            'primary userA:passA@host1:80 fallback userB:passB@host2:8080';
        final result = PythonRunner.redact(input);
        expect(result, isNot(contains('passA')));
        expect(result, isNot(contains('passB')));
        expect(result, contains('userA:***@host1:80'));
        expect(result, contains('userB:***@host2:8080'));
      });

      test('preserves the username and host portions', () {
        const input = 'myuser:topsecret@example.proxy.io:3128';
        final result = PythonRunner.redact(input);
        expect(result, contains('myuser'));
        expect(result, contains('example.proxy.io'));
        expect(result, contains('3128'));
        expect(result, isNot(contains('topsecret')));
      });
    });

    // -------------------------------------------------------------------------
    // IMAP flag redaction: --imap-pass and --imap-user
    // -------------------------------------------------------------------------
    group('--imap-pass flag', () {
      test('redacts value following --imap-pass', () {
        const input = '--imap-pass mySecretPassword';
        expect(PythonRunner.redact(input), equals('--imap-pass ***'));
      });

      test('redacts --imap-pass in the middle of a command string', () {
        const input =
            'python account_automation.py create-account --imap-pass hunter2 --other-flag value';
        final result = PythonRunner.redact(input);
        expect(result, isNot(contains('hunter2')));
        expect(result, contains('--imap-pass ***'));
        expect(result, contains('--other-flag value'));
      });

      test('redacts --imap-pass with a single-token value (no spaces in value)',
          () {
        const input = '--imap-pass abc123!';
        expect(PythonRunner.redact(input), equals('--imap-pass ***'));
      });
    });

    group('--imap-user flag', () {
      test('redacts value following --imap-user', () {
        const input = '--imap-user user@example.com';
        expect(PythonRunner.redact(input), equals('--imap-user ***'));
      });

      test('redacts --imap-user in the middle of a command string', () {
        const input =
            'python script.py --imap-user alice@mail.com --imap-pass secret';
        final result = PythonRunner.redact(input);
        expect(result, isNot(contains('alice@mail.com')));
        expect(result, isNot(contains('secret')));
        expect(result, contains('--imap-user ***'));
        expect(result, contains('--imap-pass ***'));
      });
    });

    // -------------------------------------------------------------------------
    // Strings that must not be altered
    // -------------------------------------------------------------------------
    group('non-sensitive input', () {
      test('returns empty string unchanged', () {
        expect(PythonRunner.redact(''), equals(''));
      });

      test('returns plain text with no credentials unchanged', () {
        const input = 'Script started successfully.';
        expect(PythonRunner.redact(input), equals(input));
      });

      test('does not alter URLs without passwords (host:port only)', () {
        // e.g. a bare host:port that has no user segment should not be changed.
        const input = 'Connected to proxy.example.com:8080';
        expect(PythonRunner.redact(input), equals(input));
      });

      test('does not alter flags without matching names', () {
        const input = '--email alice@example.com --world 301';
        expect(PythonRunner.redact(input), equals(input));
      });

      test('preserves non-sensitive parts of a mixed string', () {
        const input = 'user:s3cr3t@host:80 Log: account created with world=301';
        final result = PythonRunner.redact(input);
        expect(result, contains('Log: account created with world=301'));
      });
    });

    // -------------------------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------------------------
    group('edge cases', () {
      test('handles string that is only a proxy URL', () {
        expect(
          PythonRunner.redact('u:p@h:1'),
          equals('u:***@h:1'),
        );
      });

      test('handles multiple occurrences of --imap-pass on same line', () {
        // Unlikely in practice but the regex is global — both must be redacted.
        const input = '--imap-pass first --imap-pass second';
        final result = PythonRunner.redact(input);
        expect(result, isNot(contains('first')));
        expect(result, isNot(contains('second')));
      });

      test('does not redact colons that are not part of credentials', () {
        // A plain "Note: something" should not be touched.
        const input = 'Error: connection refused';
        expect(PythonRunner.redact(input), equals(input));
      });
    });
  });
}
