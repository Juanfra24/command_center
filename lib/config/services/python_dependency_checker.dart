import 'dart:io';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/scripts_path.dart';
import 'package:get/get.dart';

/// Handles checking and verifying Python and Patchright dependencies.
class PythonDependencyChecker extends GetxService {
  final isChromiumInstalled = false.obs;

  String get _scriptsPath => scriptsPath;

  /// Check if Python is available.
  Future<bool> checkPythonAvailable() async {
    try {
      final result = await Process.run('python', ['--version']);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        logger.i('Python found: $version');
        return true;
      }
    } catch (e) {
      logger.e('Python not found: $e');
    }
    return false;
  }

  /// Check if pip is available.
  Future<bool> checkPipAvailable() async {
    try {
      final result = await Process.run('python', ['-m', 'pip', '--version']);
      if (result.exitCode == 0) {
        logger.i('pip is available');
        return true;
      }
    } catch (e) {
      logger.e('pip not found: $e');
    }
    return false;
  }

  /// Check if Patchright (and dependencies) are already installed.
  Future<bool> checkDependenciesInstalled() async {
    try {
      final result = await Process.run(
        'python',
        ['-c', 'import patchright; print("OK")'],
      );

      if (result.exitCode == 0 &&
          result.stdout.toString().trim().contains('OK')) {
        logger.i('Python dependencies already installed');
        return true;
      }
    } catch (e) {
      logger.w('Dependencies check failed: $e');
    }
    return false;
  }

  /// Verify Patchright Chromium works by launching headless.
  Future<bool> verifyChromiumWorks() async {
    try {
      logger.i('Opening browser to verify Patchright installation...');
      final result = await Process.run(
        'python',
        [
          '-c',
          '''
import asyncio
from patchright.async_api import async_playwright

async def verify():
    pw = await async_playwright().start()
    browser = await pw.chromium.launch(headless=True)
    page = await browser.new_page()
    await page.goto("about:blank")
    print("CHROMIUM_OK")
    await browser.close()
    await pw.stop()

asyncio.run(verify())
'''
        ],
        workingDirectory: _scriptsPath,
      ).timeout(const Duration(seconds: 60));

      final output = result.stdout.toString();
      if (output.contains('CHROMIUM_OK')) {
        logger.i('Patchright Chromium verification successful');
        isChromiumInstalled.value = true;
        return true;
      }
      logger.w('Chromium verification failed: $output');
      return false;
    } catch (e) {
      logger.w('Chromium verification error: $e');
      return false;
    }
  }
}
