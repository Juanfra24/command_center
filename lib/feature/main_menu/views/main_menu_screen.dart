import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/src/simple/get_view.dart';

class MainmenuScreen extends GetView<MainMenuController> {
  const MainmenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.put(NativeCommandsService());
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                ), // 50px margin on each side
                child: Image.asset(
                  'assets/images/frieren_bot_command_center.jpg',
                  width: 800, // Full width minus 100px margin
                ),
              ),
              const SizedBox(height: 20), // Space between image and text
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 300,
                  vertical: 20,
                ), // More generous padding around the text
                child: Text(
                  'Welcome to the Frieren Bot Command Center, your go-to app for managing '
                  'and orchestrating your automated tasks with ease. Navigate through the app '
                  'to access various tools and services at your fingertips.',
                  style: TextStyle(
                    fontSize: 16, // Adjust font size as necessary
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              ElevatedButton(
                onPressed: () => service.listJavaProcesses(),
                child: Text('List Java Processes'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Example command
                  service.runCmdCommand('echo Hello, World!');
                },
                child: Text('Run CMD Command'),
              ),
              Obx(() =>
                  Text('Output: ${service.output}')), // Display the output
            ],
          ),
        ),
      ),
    );
  }
}
