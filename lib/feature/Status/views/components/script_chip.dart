import 'package:fluent_ui/fluent_ui.dart';

class ScriptChip extends StatelessWidget {
  final String? scriptName;
  final bool hasCharacter;
  final bool banned;
  final VoidCallback? onTap;

  const ScriptChip({
    super.key,
    this.scriptName,
    this.hasCharacter = true,
    this.banned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasCharacter) {
      return const Text('—');
    }

    if (scriptName != null) {
      return _buildScriptChip(context);
    }

    return _buildAssignChip(context);
  }

  Widget _buildScriptChip(BuildContext context) {
    final theme = FluentTheme.of(context);
    final textStyle = banned
        ? theme.typography.body?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.resources.textFillColorDisabled,
          )
        : theme.typography.body;

    return GestureDetector(
      onTap: banned ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: banned
              ? theme.resources.controlFillColorDisabled
              : Colors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: banned
                ? theme.resources.controlStrokeColorDefault
                : Colors.blue.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.settings,
              size: 12,
              color:
                  banned ? theme.resources.textFillColorDisabled : Colors.blue,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                scriptName!,
                style: textStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignChip(BuildContext context) {
    final theme = FluentTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.warningPrimaryColor.withValues(alpha: 0.6),
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.add,
              size: 12,
              color: Colors.warningPrimaryColor,
            ),
            const SizedBox(width: 4),
            Text(
              '+ Assign script',
              style: theme.typography.body?.copyWith(
                color: Colors.warningPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
