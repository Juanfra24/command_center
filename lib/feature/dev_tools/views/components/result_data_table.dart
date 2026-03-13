import 'package:fluent_ui/fluent_ui.dart';

class ResultDataTable extends StatelessWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;

  const ResultDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (columns.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No data', style: theme.typography.caption),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
              ),
              children: columns.map((col) => _buildHeaderCell(col)).toList(),
            ),
            ...rows.map((row) => TableRow(
                  children: columns
                      .map((col) => _buildDataCell(row[col], theme))
                      .toList(),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildDataCell(dynamic value, FluentThemeData theme) {
    if (value == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'NULL',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: theme.resources.textFillColorDisabled,
            fontSize: 12,
          ),
        ),
      );
    }

    final text = value.toString();
    final display = text.length > 100 ? '${text.substring(0, 100)}...' : text;

    return Tooltip(
      message: text.length > 100 ? text : '',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(display, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
