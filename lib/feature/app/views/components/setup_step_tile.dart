import 'package:command_center/config/services/setup/setup_step_state.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// A single row in the setup wizard showing step status, label, detail, and progress.
class SetupStepTile extends StatelessWidget {
  final SetupStepState state;

  const SetupStepTile({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: _buildIcon(theme),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(state.label, style: theme.typography.body),
                    Text(
                      _statusLabel,
                      style: theme.typography.caption?.copyWith(
                        color: _statusColor(theme),
                      ),
                    ),
                  ],
                ),
                if (state.detail.isNotEmpty &&
                    state.status == StepStatus.running) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.detail,
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
                ],
                if (state.status == StepStatus.running &&
                    state.progress > 0) ...[
                  const SizedBox(height: 6),
                  ProgressBar(value: state.progress * 100),
                ],
                if (state.status == StepStatus.failed) ...[
                  const SizedBox(height: 6),
                  InfoBar(
                    title: Text(state.errorMessage ?? 'Step failed'),
                    content:
                        state.fixHint != null ? Text(state.fixHint!) : null,
                    severity: InfoBarSeverity.error,
                    isLong: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(FluentThemeData theme) {
    switch (state.status) {
      case StepStatus.pending:
        return Icon(FluentIcons.circle_ring,
            size: 20, color: theme.inactiveColor);
      case StepStatus.running:
        return const SizedBox(
            width: 20, height: 20, child: ProgressRing(strokeWidth: 2));
      case StepStatus.completed:
        return Icon(FluentIcons.check_mark,
            size: 20, color: Colors.green);
      case StepStatus.failed:
        return Icon(FluentIcons.error_badge,
            size: 20, color: Colors.red);
    }
  }

  String get _statusLabel {
    switch (state.status) {
      case StepStatus.pending:
        return 'Pending';
      case StepStatus.running:
        return 'Running';
      case StepStatus.completed:
        return 'Complete';
      case StepStatus.failed:
        return 'Failed';
    }
  }

  Color _statusColor(FluentThemeData theme) {
    switch (state.status) {
      case StepStatus.pending:
        return theme.inactiveColor;
      case StepStatus.running:
        return theme.accentColor;
      case StepStatus.completed:
        return Colors.green;
      case StepStatus.failed:
        return Colors.red;
    }
  }
}
