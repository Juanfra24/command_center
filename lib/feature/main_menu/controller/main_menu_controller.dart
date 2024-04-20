import 'package:get/get.dart' hide Response;

import '../../../config/services/firestore_service.dart';
import '../../../core/helper/logger.dart';

class MainMenuController extends GetxController {
  var isLoading = false.obs;
  final FirestoreService _firestoreService = Get.find();

  Future<void> demoGetCall() async {
    try {
      var documents = await _firestoreService.getAllDocuments('proxies');
      for (var document in documents) {
        print(document);
      }
    } catch (err) {
      logger.e(err);
    }
  }
}
