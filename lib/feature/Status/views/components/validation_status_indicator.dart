import 'package:command_center/config/services/automation/automation_result.dart';
import 'package:command_center/config/services/automation/automation_service.dart';
import 'package:command_center/config/theme/status_colors.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';

class ValidationStatusIndicator extends StatelessWidget {
  final ValueNotifier<bool> isValidating;
  final ValueNotifier<AutomationResult?> validationResult;

  const ValidationStatusIndicator({
    super.key,
    required this.isValidating,
    required this.validationResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: isValidating,
      builder: (context, validating, _) {
        return ValueListenableBuilder<AutomationResult?>(
          valueListenable: validationResult,
          builder: (context, result, _) {
            if (validating) {
              return _buildValidatingState(context, theme);
            }
            if (result != null) {
              return _buildResultState(context, theme, result);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildValidatingState(BuildContext context, FluentThemeData theme) {
    final colors = StatusColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.infoBg(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validating Proxy Connection...',
                  style: theme.typography.bodyStrong,
                ),
                Text(
                  'Opening browser and checking IP address',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
          HyperlinkButton(
            onPressed: () async {
              final automationService = Get.find<AutomationService>();
              await automationService.cancelCurrentTask();
              isValidating.value = false;
              validationResult.value =
                  AutomationResult.error('Validation cancelled');
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultState(
      BuildContext context, FluentThemeData theme, AutomationResult result) {
    final colors = StatusColors.of(context);
    final isSuccess = result.isSuccess;
    final isAccountCreated = result.isAccountCreated;
    final color = isSuccess ? colors.success : colors.error;
    final icon = isSuccess ? FluentIcons.check_mark : FluentIcons.error_badge;

    String title;
    if (isAccountCreated) {
      title = 'Account Created Successfully';
    } else if (isSuccess) {
      title = 'Proxy Validated Successfully';
    } else {
      title = 'Operation Failed';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.bodyStrong?.copyWith(color: color),
                ),
                if (result.actualIp != null)
                  Text(
                    'IP: ${result.actualIp}',
                    style: theme.typography.caption,
                  ),
                if (isAccountCreated && result.data != null) ...[
                  if (result.data!['accountName'] != null)
                    Text(
                      'Name: ${result.data!['accountName']}',
                      style: theme.typography.caption,
                    ),
                  if (result.data!['email'] != null)
                    Text(
                      'Email: ${result.data!['email']}',
                      style: theme.typography.caption,
                    ),
                  if (result.data!['password'] != null)
                    Text(
                      'Password: \u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                      style: theme.typography.caption,
                    ),
                ],
                if (!isSuccess)
                  Text(
                    result.message,
                    style: theme.typography.caption?.copyWith(color: color),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
