/// Status codes for automation operations (matches Python enum)
enum AutomationStatus {
  success,
  proxyValidationFailed,
  browserError,
  timeout,
  captchaRequired,
  accountCreated,
  unknownError;

  factory AutomationStatus.fromString(String value) {
    switch (value) {
      case 'success':
        return AutomationStatus.success;
      case 'proxy_validation_failed':
        return AutomationStatus.proxyValidationFailed;
      case 'browser_error':
        return AutomationStatus.browserError;
      case 'timeout':
        return AutomationStatus.timeout;
      case 'captcha_required':
        return AutomationStatus.captchaRequired;
      case 'account_created':
        return AutomationStatus.accountCreated;
      default:
        return AutomationStatus.unknownError;
    }
  }
}

/// Result of an automation operation
class AutomationResult {
  final AutomationStatus status;
  final String message;
  final String? expectedIp;
  final String? actualIp;
  final Map<String, dynamic>? data;

  AutomationResult({
    required this.status,
    required this.message,
    this.expectedIp,
    this.actualIp,
    this.data,
  });

  factory AutomationResult.fromJson(Map<String, dynamic> json) {
    return AutomationResult(
      status: AutomationStatus.fromString(json['status'] ?? 'unknown_error'),
      message: json['message'] ?? 'Unknown error',
      expectedIp: json['expected_ip'],
      actualIp: json['actual_ip'],
      data: json['data'],
    );
  }

  factory AutomationResult.error(String message) {
    return AutomationResult(
      status: AutomationStatus.unknownError,
      message: message,
    );
  }

  bool get isSuccess =>
      status == AutomationStatus.success ||
      status == AutomationStatus.accountCreated;
  bool get isAccountCreated => status == AutomationStatus.accountCreated;
  bool get needsCaptcha => status == AutomationStatus.captchaRequired;
  bool get proxyFailed => status == AutomationStatus.proxyValidationFailed;
}
