import 'dart:io';
import 'package:command_center/core/helper/logger.dart';
import 'package:command_center/core/helper/python_resolver.dart';
import 'package:command_center/core/helper/scripts_path.dart';
import 'package:get/get.dart';

/// Handles checking and verifying Python and Patchright dependencies.
class PythonDependencyChecker extends GetxService {
  bool isChromiumInstalled = false;

  String get _scriptsPath => scriptsPath;

  /// Check if Python is available.
  Future<bool> checkPythonAvailable() async {
    try {
      final python = await PythonResolver.executable;
      final result = await Process.run(python, ['--version']);
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
      final python = await PythonResolver.executable;
      final result = await Process.run(python, ['-m', 'pip', '--version']);
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
      final python = await PythonResolver.executable;
      final result = await Process.run(
        python,
        ['-c', 'import patchright; import requests; print("OK")'],
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

  /// Verify browser works by launching headless.
  /// Tries Chrome first (preferred for Cloudflare), falls back to Chromium.
  Future<bool> verifyChromiumWorks() async {
    try {
      logger.i('Verifying browser installation...');
      final python = await PythonResolver.executable;
      final result = await Process.run(
        python,
        [
          '-c',
          '''
import asyncio
from patchright.async_api import async_playwright

async def verify():
    pw = await async_playwright().start()
    browser = None
    channel_used = "unknown"
    for channel in ("chrome", None):
        try:
            browser = await pw.chromium.launch(headless=True, channel=channel)
            channel_used = channel or "chromium"
            break
        except Exception:
            if channel is None:
                raise
    page = await browser.new_page()
    await page.goto("about:blank")
    print(f"BROWSER_OK:{channel_used}")
    await browser.close()
    await pw.stop()

asyncio.run(verify())
'''
        ],
        workingDirectory: _scriptsPath,
      ).timeout(const Duration(seconds: 60));

      final output = result.stdout.toString();
      if (output.contains('BROWSER_OK')) {
        final channel =
            output.contains('BROWSER_OK:chrome') ? 'Chrome' : 'Chromium';
        logger.i('Browser verification successful ($channel)');
        isChromiumInstalled = true;
        return true;
      }
      logger.w('Browser verification failed: $output');
      return false;
    } catch (e) {
      logger.w('Browser verification error: $e');
      return false;
    }
  }
}
