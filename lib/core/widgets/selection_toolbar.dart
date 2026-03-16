import 'package:fluent_ui/fluent_ui.dart';

class SelectionAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const SelectionAction({
    required this.label,
    this.icon,
    required this.onPressed,
  });
}

class SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final List<SelectionAction> actions;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final bool allSelected;

  const SelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.actions,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.allSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).accentColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Checkbox(
            checked: allSelected,
            onChanged: (_) =>
                allSelected ? onClearSelection() : onSelectAll(),
          ),
          const SizedBox(width: 8),
          Text(
            '$selectedCount selected',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(width: 16),
          ...actions.map((action) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Button(
                  onPressed: action.onPressed,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      Colors.white.withValues(alpha: 0.15),
                    ),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (action.icon != null) ...[
                        Icon(action.icon, size: 12, color: Colors.white),
                        const SizedBox(width: 6),
                      ],
                      Text(action.label),
                    ],
                  ),
                ),
              )),
          const Spacer(),
          HyperlinkButton(
            onPressed: onClearSelection,
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                Colors.white.withValues(alpha: 0.6),
              ),
            ),
            child: const Text('Clear selection'),
          ),
        ],
      ),
    );
  }
}
