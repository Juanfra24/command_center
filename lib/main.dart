import 'package:command_center/feature/app.dart';
import 'package:command_center/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'core/resource/widgets/custom_error_widget.dart';
import 'package:window_manager/window_manager.dart';

final GlobalKey<NavigatorState> globalNavKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Set window properties
  windowManager.waitUntilReadyToShow().then(
    (_) async {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setSize(const Size(1280, 800));
      await windowManager.setResizable(false);
      await windowManager.show();
    },
  );
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GetStorage.init();
  FlutterError.onError = (FlutterErrorDetails details) {
    globalNavKey.currentState?.pushReplacement(
      MaterialPageRoute(
        builder: (context) => CustomErrorScreen(errorDetails: details),
      ),
    );
  };

  runApp(const App());
}
