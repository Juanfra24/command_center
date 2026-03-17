import 'package:get/get.dart';

class StatusSelectionController extends GetxController {
  // GetX has no RxSet — use RxList with deduplication guards
  final selectedIds = <int>[].obs;
  final searchQuery = ''.obs;
  final statusFilter = 'all'.obs;
  final scriptFilter = 'all'.obs;
  final filteredCount = 0.obs;

  bool isSelected(int id) => selectedIds.contains(id);

  void toggleSelection(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  void selectAll(List<int> ids) {
    selectedIds.clear();
    selectedIds.addAll(ids);
  }

  void clearSelection() {
    selectedIds.clear();
  }

  bool get hasSelection => selectedIds.isNotEmpty;

  int get selectedCount => selectedIds.length;
}
