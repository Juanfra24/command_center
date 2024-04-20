import 'package:get/get.dart';
import 'package:flutter/services.dart';

class NativeCommandsService extends GetxController {
  // Platform channel setup
  static const platform = MethodChannel('com.onemanco/commands');

  // Rx variable to hold the output of commands
  var output = ''.obs;

  // Method to list Java processes
  Future<void> listJavaProcesses() async {
    try {
      final String result = await platform.invokeMethod('listJavaProcesses');
      output.value = result;
    } on PlatformException catch (e) {
      output.value = "Failed to list Java processes: '${e.message}'.";
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
