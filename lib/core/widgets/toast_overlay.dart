import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:command_center/config/services/notification_service.dart';
import 'package:command_center/core/widgets/toast_card.dart';
import 'package:command_center/core/widgets/toast_data.dart';

class ToastOverlay extends StatefulWidget {
  final Widget child;

  const ToastOverlay({super.key, required this.child});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  final List<_ActiveToast> _toasts = [];
  StreamSubscription<ToastData>? _subscription;

  @override
  void initState() {
    super.initState();
    final service = Get.find<NotificationService>();
    _subscription = service.toastStream.listen(_onToast);
  }

  void _onToast(ToastData toast) {
    final active = _ActiveToast(toast: toast);
    setState(() => _toasts.add(active));

    // Auto-dismiss non-errors after 5s
    if (toast.severity != ToastSeverity.error) {
      active.autoRemoveTimer = Timer(const Duration(seconds: 5), () {
        _dismiss(active);
      });
    }
  }

  void _dismiss(_ActiveToast active) {
    active.autoRemoveTimer?.cancel();
    if (mounted && _toasts.contains(active)) {
      setState(() => _toasts.remove(active));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final t in _toasts) {
      t.autoRemoveTimer?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _toasts.reversed
                .take(5)
                .map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ToastCard(
                        toast: t.toast,
                        onDismiss: () => _dismiss(t),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ActiveToast {
  final ToastData toast;
  Timer? autoRemoveTimer;
  _ActiveToast({required this.toast});
}
