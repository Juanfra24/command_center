import 'package:command_center/data/database_service.dart';
import 'package:get/get.dart' hide Response;

import '../../../core/helper/logger.dart';

class MainMenuController extends GetxController {
  Future<void> demoGetCall() async {
    try {
      final dbService = Get.find<DatabaseService>();
      final slots = await dbService.proxyRepository.getAllSlots();
      for (var slot in slots) {
        logger.i('Slot: ${slot.slotName}');
      }
    } catch (err) {
      logger.e(err);
    }
  }
}
