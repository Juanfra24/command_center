import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the application support directory for all persistent file storage.
/// Injected via GetX DI so services never hardcode paths.
class AppDataPath {
  String? _cachedPath;

  /// Returns the base application data path.
  /// Typically: C:\Users\<user>\AppData\Roaming\com.example.command_center\
  Future<String> get basePath async {
    _cachedPath ??= (await getApplicationSupportDirectory()).path;
    return _cachedPath!;
  }

  /// Pure path join — no I/O, safe for testing.
  static String joinPath(String base, String subDir) {
    return p.join(base, subDir);
  }
}
