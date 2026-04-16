import 'package:fluent_ui/fluent_ui.dart';

enum LoadingButtonStyle { filled, outline }

class LoadingButton extends StatefulWidget {
  final String label;
  final String? loadingLabel;
  final String? successLabel;
  final String? errorLabel;
  final Future<void> Function()? onPressed;
  final LoadingButtonStyle style;
  final IconData? icon;

  const LoadingButton({
    super.key,
    required this.label,
    this.loadingLabel,
    this.successLabel,
    this.errorLabel,
    this.onPressed,
    this.style = LoadingButtonStyle.filled,
    this.icon,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

enum _ButtonState { idle, loading, success, error }

class _LoadingButtonState extends State<LoadingButton> {
  _ButtonState _state = _ButtonState.idle;

  Future<void> _handlePress() async {
    if (_state != _ButtonState.idle || widget.onPressed == null) return;

    setState(() => _state = _ButtonState.loading);
    try {
      await widget.onPressed!();
      if (!mounted) return;
      setState(() => _state = _ButtonState.success);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _state = _ButtonState.idle);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _ButtonState.error);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _state = _ButtonState.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_state == _ButtonState.loading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 14,
              height: 14,
              child: ProgressRing(strokeWidth: 2),
            ),
          )
        else if (_state == _ButtonState.success)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(FluentIcons.completed, size: 14),
          )
        else if (widget.icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(widget.icon, size: 14),
          ),
        Text(_currentLabel),
      ],
    );

    final onPressed = _state == _ButtonState.idle ? _handlePress : null;

    return widget.style == LoadingButtonStyle.filled
        ? FilledButton(onPressed: onPressed, child: child)
        : Button(onPressed: onPressed, child: child);
  }

  String get _currentLabel => switch (_state) {
        _ButtonState.loading => widget.loadingLabel ?? widget.label,
        _ButtonState.success => widget.successLabel ?? 'Done',
        _ButtonState.error => widget.errorLabel ?? 'Failed',
        _ => widget.label,
      };
}
