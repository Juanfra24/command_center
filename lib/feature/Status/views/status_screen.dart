import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/simple/get_view.dart';

class StatusScreen extends GetView<MainMenuController> {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20), // Space between image and text
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 300,
                  vertical: 20,
                ), // More generous padding around the text
                child: Text(
                  'NEW SCREEEEEN',
                  style: TextStyle(
                    fontSize: 16, // Adjust font size as necessary
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
