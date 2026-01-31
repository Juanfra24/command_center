import 'dart:async';
import 'dart:io';

import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/core/constants/db_collections.dart';
import 'package:command_center/feature/Status/data/jagex_account_model.dart';
import 'package:command_center/feature/Status/data/process_model.dart';
import 'package:command_center/feature/Status/data/proxy_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;

import '../../../config/services/firestore_service.dart';
import '../../../core/helper/logger.dart';

Future<void> handleStream(Stream<List<int>> stream, IOSink fileSink) async {
  StreamSubscription<List<int>>? subscription;
  try {
    subscription = stream.listen(
      (data) {
        stdout.add(data); // Echo to standard output
        fileSink.add(data); // Write to file
      },
      onDone: () {
        subscription?.cancel();
      },
      onError: (e) {
        print('Error from stream: $e');
        subscription?.cancel();
      },
      cancelOnError: true,
    );
  } catch (e) {
    print('Failed to handle stream: $e');
  }
}

class StatusController extends GetxController {
  var isLoading = true.obs;
  Timer? _processCheckTimer;
  List<JagexAccount> accountList = <JagexAccount>[].obs;
  List<int> processList = <int>[].obs;
  RxMap<String, ProcessClient> processClients =
      <String, ProcessClient>{}.obs; // Maps character names to their processes

  final FirestoreService _firestoreService = Get.find();
  final NativeCommandsService _nativeCommandsService = Get.find();

  @override
  void onInit() async {
    super.onInit();
    await getAccountsData().then((_) {
      updateRunningProcesses();
      _startProcessCheckTimer();
    });
    isLoading.value = false;
  }

  void _startProcessCheckTimer() {
    _processCheckTimer?.cancel(); // Cancel any existing timer
    _processCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      updateRunningProcesses();
    });
  }

  Future<void> updateRunningProcesses() async {
    var javaProcesses = await _nativeCommandsService.listJavaProcesses();
    var newRunningProcesses = <String, ProcessClient>{};
    for (var process in javaProcesses) {
      var match = RegExp(r'-script "(.*?)" -account "(.*?)"')
          .firstMatch(process.commandLine);
      if (match != null) {
        var characterName = match.group(2);
        if (characterName != null) {
          newRunningProcesses[characterName] = process;
        }
      }
    }
    processClients.value = newRunningProcesses;
  }

  Future<void> getAccountsData() async {
    try {
      var accounts = await _firestoreService.getAllDocuments(accountCollection);
      accountList
        ..clear()
        ..addAll(
            [for (var account in accounts) JagexAccount.fromJson(account)]);
    } catch (err) {
      logger.e(err);
    }
  }

  void copyToClipboard(String text, BuildContext context) {
    Clipboard.setData(ClipboardData(text: text)).then(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to Clipboard!')));
      },
    );
  }

  Future<Proxy> getProxyDoc(String proxyAddress) async {
    try {
      var proxyMap = await _firestoreService.getDocumentById(
          proxiesCollection, proxyAddress);

      return Proxy.fromJson(proxyMap ?? {});
    } catch (err) {
      logger.e(err);
      return Proxy.empty();
    }
  }

  Future<void> runPythonScript(String proxyAddress) async {
    try {
      Proxy proxy = await getProxyDoc(proxyAddress);
      var pythonExecutable = 'scripts/.venv/Scripts/python.exe';
      var scriptPath = 'scripts/openChrome.py';
      var argument = proxyAddress == "none" ? "none" : proxy.generateProxyUrl();

      // Generating a timestamped filename in the scripts/log folder
      String fileName =
          DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_');
      File outputFile = File('scripts/logs/${fileName}_output.txt');
      IOSink fileSink = outputFile.openWrite(mode: FileMode.append);

      var installProcess = await Process.start(pythonExecutable,
          ['-m', 'pip', 'install', '-r', 'scripts/requirements.txt']);
      installProcess.stdout.asBroadcastStream();
      installProcess.stderr.asBroadcastStream();

      // Handle process output and errors using the new function
      handleStream(installProcess.stdout, fileSink);
      handleStream(installProcess.stderr, fileSink);

      var installExitCode = await installProcess.exitCode;
      print('Dependency installation exit code: $installExitCode');

      if (installExitCode == 0) {
        var process =
            await Process.start(pythonExecutable, [scriptPath, argument]);
        processList.add(process.pid);
        process.stdout.asBroadcastStream();
        process.stderr.asBroadcastStream();

        // Handle the Python script's output in the same way
        handleStream(process.stdout, fileSink);
        handleStream(process.stderr, fileSink);

        var exitCode = await process.exitCode;
        processList.remove(process.pid);
        print('Python script exit code: $exitCode');
      } else {
        print('Failed to install dependencies.');
      }
      await fileSink.flush();
      await fileSink.close();
    } catch (e) {
      print('Failed to run Python script: $e');
    }
  }

  Future<void> runGameClient(JagexAccount account) async {
    try {
      var proxy = account.proxyAddress == "none" ? null : account.proxyAddress;
      await _nativeCommandsService.runGameClient(
        characterName: account.characters[0].name,
        proxyAddress: proxy,
        scriptName: null,
      );
      sleep(const Duration(milliseconds: 100));
      await updateRunningProcesses(); // Update immediately after starting
      _startProcessCheckTimer(); // Restart the timer to ensure it's running
    } catch (e) {
      print('Failed to run game script: $e');
    }
  }

  Future<void> stopGameClient(ProcessClient? process) async {
    if (process != null) {
      await _nativeCommandsService.killProcess(process.processId);
      sleep(const Duration(milliseconds: 100));
      updateRunningProcesses(); // Refresh the running process list
      _startProcessCheckTimer(); // Restart the timer to ensure it's running
    }
  }

  @override
  void onClose() async {
    for (var processId in processList) {
      await _nativeCommandsService.killProcess(processId);
    }
    _processCheckTimer?.cancel();
    super.onClose();
  }
}
