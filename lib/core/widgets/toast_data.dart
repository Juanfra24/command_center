enum ToastSeverity { success, info, warning, error }

class ToastData {
  final String title;
  final String? subtitle;
  final ToastSeverity severity;
  final DateTime timestamp;

  ToastData({
    required this.title,
    this.subtitle,
    required this.severity,
  }) : timestamp = DateTime.now();
}
