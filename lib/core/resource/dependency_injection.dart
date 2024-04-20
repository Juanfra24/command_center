import 'package:command_center/config/services/firestore_service.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/feature/Status/controller/status_controller.dart';
import 'package:command_center/feature/main_menu/controller/main_menu_controller.dart';
import 'package:command_center/feature/music/controller/music_controller.dart';
import 'package:get/get.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.putAsync<FirestoreService>(() async => await FirestoreService().init());
    Get.put<MusicController>(MusicController(), permanent: true);
    Get.put<NativeCommandsService>(NativeCommandsService(), permanent: true);

    Get.lazyPut<MainMenuController>(() => MainMenuController());
    Get.lazyPut<StatusController>(() => StatusController());
  }
}
