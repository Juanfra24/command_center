import 'package:command_center/feature/Status/data/proxy.dart';
import 'package:get/get.dart' hide Response;

import '../../../config/services/firestore_service.dart';
import '../../../core/helper/logger.dart';

class StatusController extends GetxController {
  var isLoading = true.obs;
  final FirestoreService _firestoreService = Get.find();

  @override
  void onInit() {
    super.onInit();
    getProxieData();
  }

  Future<void> getProxieData() async {
    try {
      var documents = await _firestoreService.getAllDocuments('proxies');
      for (var document in documents) {
        Proxy proxyInfo = Proxy.fromJson(document);
        // You can now use `proxyInfo` for your application logic, such as displaying data or further processing
        print(
            proxyInfo); // This will require you to override toString in ProxyInfo if you want a custom output
      }
    } catch (err) {
      logger.e(err);
    }
  }
}
