import 'package:get_storage/get_storage.dart';

class LocalStorage {
  static Future<void> set({required String key, required dynamic value}) {
    return GetStorage().write("token", value);
  }

  static dynamic get({required String key}) {
    return GetStorage().read("token");
  }
}
