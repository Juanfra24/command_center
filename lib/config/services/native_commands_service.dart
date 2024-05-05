import 'dart:convert';

import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';

class NativeCommandsService extends GetxController {
  // Platform channel setup
  static const platform = MethodChannel('com.onemanco/commands');

  // Rx variable to hold the output of commands
  var output = ''.obs;

  // Method to list Java processes
  Future<List<ProcessClient>> listJavaProcesses() async {
    try {
      final String encoded = await platform.invokeMethod('listJavaProcesses');
      final bytes = base64Decode(encoded);
      return ProcessClient.parseProcessData(bytes);
    } on PlatformException catch (e) {
      print('Failed to get Java processes: ${e.message}');
      return [];
    }
  }

  // Method to kill a process and al his decendants
  Future<void> killProcess(int pid) async {
    try {
      final String result =
          await platform.invokeMethod('killProcessAndChilds', {'pid': pid});
      output.value = result;
    } on PlatformException catch (e) {
      output.value = "Failed to kill those process: '${e.message}'.";
    }
  }

  // Method that run a game client with an specific script
  Future<void> runGameClient({
    required String characterName,
    required String? proxyAddress,
    String? scriptName = 'Tutorial Journey',
  }) async {
    try {
      final String result = await platform.invokeMethod('runGameClient', {
        'characterName': characterName,
        'proxyAddress': proxyAddress ?? 'none',
        'scriptName': scriptName ?? 'Tutorial Journey',
      });
      print('Success: $result');
    } on PlatformException catch (e) {
      print('Failed to run game client: ${e.message}');
    } catch (e) {
      print('An unexpected error occurred: $e');
    }
  }

  // Method to run a generic CMD command
  Future<void> runCmdCommand(String command) async {
    try {
      final String result =
          await platform.invokeMethod('runCmdCommand', {'command': command});
      output.value = result;
    } on PlatformException catch (e) {
      output.value = "Failed to run CMD command: '${e.message}'.";
    }
  }
}
