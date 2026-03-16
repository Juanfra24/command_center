import 'package:flutter_test/flutter_test.dart';
import 'package:command_center/feature/Status/controller/status_selection_controller.dart';

void main() {
  late StatusSelectionController controller;

  setUp(() {
    controller = StatusSelectionController();
  });

  group('selection', () {
    test('toggleSelection adds and removes IDs', () {
      controller.toggleSelection(1);
      expect(controller.selectedIds, contains(1));
      controller.toggleSelection(1);
      expect(controller.selectedIds, isEmpty);
    });

    test('selectAll replaces with provided IDs (no duplicates)', () {
      controller.selectAll([1, 2, 3]);
      expect(controller.selectedIds.length, 3);
      controller.selectAll([1, 2, 3, 4]);
      expect(controller.selectedIds.length, 4);
    });

    test('clearSelection empties selection', () {
      controller.selectAll([1, 2, 3]);
      controller.clearSelection();
      expect(controller.selectedIds, isEmpty);
    });

    test('isSelected returns correct state', () {
      controller.toggleSelection(1);
      expect(controller.isSelected(1), isTrue);
      expect(controller.isSelected(2), isFalse);
    });
  });

  group('filtering', () {
    test('searchQuery is observable', () {
      controller.searchQuery.value = 'test';
      expect(controller.searchQuery.value, 'test');
    });

    test('statusFilter defaults to all', () {
      expect(controller.statusFilter.value, 'all');
    });

    test('scriptFilter defaults to all', () {
      expect(controller.scriptFilter.value, 'all');
    });
  });
}
