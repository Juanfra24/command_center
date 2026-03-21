import 'dart:io';

/// Centralized, user-friendly error messages for setup failures.
class SetupMessages {
  static ({String error, String hint}) pythonNotFound() => (
        error: 'Python 3.8+ is required',
        hint: Platform.isWindows
            ? "Download from python.org and check 'Add to PATH'"
            : 'Run: sudo apt install python3 python3-pip',
      );

  static ({String error, String hint}) pipNotFound() => (
        error: 'pip is required for dependency installation',
        hint: Platform.isWindows
            ? 'Reinstall Python with pip enabled'
            : 'Run: sudo apt install python3-pip python3-venv',
      );

  static ({String error, String hint}) scriptsExtractionFailed() => (
        error: 'Failed to extract application scripts',
        hint: Platform.isWindows
            ? 'Reinstall the application'
            : 'Reinstall the AppImage',
      );

  static ({String error, String hint}) pipInstallFailed() => (
        error: 'Failed to install Python dependencies',
        hint: 'Check your internet connection and retry',
      );

  static ({String error, String hint}) chromiumInstallFailed() => (
        error: 'Browser driver installation failed',
        hint: 'Check your internet connection and retry',
      );

  static ({String error, String hint}) javaDownloadFailed() => (
        error: 'Failed to download Java 17',
        hint: 'Check your internet connection and retry',
      );

  static ({String error, String hint}) javaExtractionFailed() => (
        error: 'Failed to extract Java runtime',
        hint: 'Check available disk space and retry',
      );

  static ({String error, String hint}) githubPatMissing() => (
        error: 'GitHub access token not configured',
        hint: 'Configure your GitHub PAT in Settings after setup completes',
      );

  static ({String error, String hint}) jarDownloadFailed() => (
        error: 'Failed to download Microbot engine',
        hint: 'Check internet connection and GitHub PAT',
      );

  static ({String error, String hint}) requirementsTxtMissing() => (
        error: 'Python dependency list not found',
        hint: Platform.isWindows
            ? 'Reinstall the application'
            : 'Reinstall the AppImage',
      );
}
