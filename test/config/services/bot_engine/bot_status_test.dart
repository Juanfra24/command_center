import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/config/services/bot_engine/bot_status.dart';

void main() {
  group('BotStatus', () {
    test('fromJson parses full status response', () {
      final json = {
        'version': 1,
        'characterId': 42,
        'characterName': 'BotAccount1',
        'status': 'running',
        'script': {'name': 'Auto Woodcutting', 'running': true, 'runtime': 3600},
        'player': {
          'world': 301,
          'location': {'x': 3222, 'y': 3218},
          'hitpoints': 45,
          'prayer': 0,
          'runEnergy': 78,
        },
        'xp': {
          'totalGained': 12450,
          'perHour': 35000,
          'skills': {
            'woodcutting': {'current': 45, 'gained': 12450},
          },
        },
        'uptime': 3600,
        'loggedIn': true,
      };

      final status = BotStatus.fromJson(json);

      expect(status.version, 1);
      expect(status.status, 'running');
      expect(status.scriptName, 'Auto Woodcutting');
      expect(status.scriptRunning, true);
      expect(status.scriptRuntime, 3600);
      expect(status.world, 301);
      expect(status.hitpoints, 45);
      expect(status.prayer, 0);
      expect(status.runEnergy, 78);
      expect(status.totalXpGained, 12450);
      expect(status.xpPerHour, 35000);
      expect(status.uptime, 3600);
      expect(status.loggedIn, true);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'version': 1,
        'status': 'login_screen',
        'script': {'running': false, 'runtime': 0},
        'player': {},
        'xp': {'totalGained': 0, 'perHour': 0, 'skills': {}},
        'uptime': 10,
        'loggedIn': false,
      };

      final status = BotStatus.fromJson(json);

      expect(status.scriptName, isNull);
      expect(status.world, isNull);
      expect(status.hitpoints, 0);
      expect(status.loggedIn, false);
    });

    test('fromJson tolerates unknown fields (additive schema)', () {
      final json = {
        'version': 2,
        'status': 'running',
        'script': {'name': 'Test', 'running': true, 'runtime': 100},
        'player': {'world': 301},
        'xp': {'totalGained': 0, 'perHour': 0, 'skills': {}},
        'uptime': 100,
        'loggedIn': true,
        'newFieldFromFuture': 'should be ignored',
      };

      final status = BotStatus.fromJson(json);
      expect(status.version, 2);
    });
  });
}
