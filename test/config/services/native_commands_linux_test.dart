import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/native_commands_linux.dart';

void main() {
  group('NativeCommandsLinux', () {
    group('parsePsOutput', () {
      test('parses java process from ps output', () {
        const output =
            '  1234 java            java -jar /app/bot.jar --cc-profile-dir=/profiles/bot-42\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 1);
        expect(result.first.processId, 1234);
        expect(result.first.commandLine, contains('--cc-profile-dir'));
        expect(result.first.commandLine, contains('bot-42'));
      });

      test('filters non-java processes', () {
        const output = '  5678 python          python script.py\n'
            '  1234 java            java -jar bot.jar\n'
            '  9999 node            node server.js\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 1);
        expect(result.first.processId, 1234);
      });

      test('handles empty output', () {
        final result = NativeCommandsLinux.parsePsOutput('');
        expect(result, isEmpty);
      });

      test('handles multiple java processes', () {
        const output =
            '  1001 java            java -jar bot.jar --cc-profile-dir=/p/bot-1\n'
            '  1002 java            java -jar bot.jar --cc-profile-dir=/p/bot-2\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 2);
        expect(result[0].processId, 1001);
        expect(result[1].processId, 1002);
      });

      test('handles whitespace variations in ps output', () {
        const output = '1234 java java -jar test.jar\n';
        final result = NativeCommandsLinux.parsePsOutput(output);
        expect(result.length, 1);
        expect(result.first.processId, 1234);
      });
    });
  });
}
