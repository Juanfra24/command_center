import 'package:fluent_ui/fluent_ui.dart';

class ResultDataTable extends StatelessWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;

  static const double _cellWidth = 150.0;
  static const double _headerHeight = 36.0;
  static const double _rowHeight = 32.0;

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

    final tableWidth = columns.length * _cellWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed header
            Container(
              height: _headerHeight,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Row(
                children: columns.map((col) => _buildHeaderCell(col)).toList(),
              ),
            ),
            // Virtualized rows
            Flexible(
              child: ListView.builder(
                itemCount: rows.length,
                itemExtent: _rowHeight,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.resources.dividerStrokeColorDefault,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: columns
                          .map((col) => _buildDataCell(rows[index][col], theme))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return SizedBox(
      width: _cellWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDataCell(dynamic value, FluentThemeData theme) {
    if (value == null) {
      return SizedBox(
        width: _cellWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'NULL',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: theme.resources.textFillColorDisabled,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final text = value.toString();
    final display = text.length > 100 ? '${text.substring(0, 100)}...' : text;

    return Tooltip(
      message: text.length > 100 ? text : '',
      child: SizedBox(
        width: _cellWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            display,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
