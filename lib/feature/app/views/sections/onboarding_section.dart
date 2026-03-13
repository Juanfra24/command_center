import 'package:command_center/config/services/onboarding_service.dart';
import 'package:command_center/feature/app/views/components/setup_checklist_item.dart';
import 'package:command_center/feature/app/views/dialogs/ipqs_onboarding_dialog.dart';
import 'package:command_center/feature/app/views/dialogs/webshare_config_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';

class OnboardingSection extends StatelessWidget {
  final OnboardingService? onboardingService;

  const OnboardingSection({super.key, required this.onboardingService});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: const PageHeader(title: Text('Welcome')),
      content: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    FluentIcons.rocket,
                    size: 40,
                    color: theme.accentColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Get Started',
                  style: theme.typography.subtitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect your Webshare account to sync proxy slots and start managing your bots.',
                  style: theme.typography.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildSetupChecklist(context),
                const SizedBox(height: 16),
                Text(
                  'Click the step above to begin setup',
                  style: theme.typography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupChecklist(BuildContext context) {
    final isWebshareComplete =
        onboardingService?.isWebshareConfigured.value ?? false;
    final isIpqsComplete = onboardingService?.isIpqsConfigured.value ?? false;

    return Column(
      children: [
        SetupChecklistItem(
          title: 'Connect Webshare & Sync Proxies',
          subtitle: 'Connect your proxy provider and import slots',
          isComplete: isWebshareComplete,
          onTap: () => WebshareConfigDialog.show(context),
        ),
        const SizedBox(height: 12),
        SetupChecklistItem(
          title: 'Configure IPQualityScore',
          subtitle: 'Enable IP scoring and fraud detection',
          isComplete: isIpqsComplete,
          isEnabled: isWebshareComplete,
          onTap: () => IpqsOnboardingDialog.show(context),
        ),
      ],
    );
  }
}
