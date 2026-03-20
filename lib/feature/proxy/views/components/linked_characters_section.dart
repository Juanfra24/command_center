import 'package:command_center/domain/entities/character.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Displays the list of characters linked to a proxy slot.
/// Receives a flat list of [CharacterEntity] items (obtained by expanding
/// the accounts that belong to the slot).
class LinkedCharactersSection extends StatelessWidget {
  final List<CharacterEntity> characters;

  const LinkedCharactersSection({super.key, required this.characters});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (characters.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(FluentIcons.contact, size: 32),
                const SizedBox(height: 8),
                Text('No characters linked', style: theme.typography.body),
                const SizedBox(height: 4),
                Text(
                  'Assign an account to this proxy slot to see characters here',
                  style: theme.typography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: characters.map((c) => _buildRow(c, theme)).toList(),
      ),
    );
  }

  Widget _buildRow(CharacterEntity character, FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: character.banned
                  ? Colors.red.withValues(alpha: 0.15)
                  : theme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                character.banned ? FluentIcons.blocked : FluentIcons.people,
                size: 16,
                color: character.banned ? Colors.red : theme.accentColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: theme.typography.bodyStrong,
                ),
                if ((character.defaultScriptName ?? '').isNotEmpty)
                  Text(
                    character.defaultScriptName!,
                    style: theme.typography.caption,
                  ),
              ],
            ),
          ),
          if (character.banned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Banned',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
