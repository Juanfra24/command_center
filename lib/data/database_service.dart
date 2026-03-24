import 'package:get/get.dart';

import 'database/app_database.dart';
import 'repositories/account_repository_impl.dart';
import 'repositories/config_repository_impl.dart';
import 'repositories/notification_repository_impl.dart';
import 'repositories/proxy_repository_impl.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/config_repository.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/proxy_repository.dart';

/// Service that manages the database and repository instances
/// This is the main entry point for data access in the application
class DatabaseService extends GetxService {
  late final AppDatabase _database;

  late final ConfigRepository configRepository;
  late final ProxyRepository proxyRepository;
  late final AccountRepository accountRepository;
  late final NotificationRepository notificationRepository;

  DatabaseService();

  /// Test-only constructor: injects an in-memory [AppDatabase].
  DatabaseService.forTesting(AppDatabase db) {
    _database = db;
    configRepository = ConfigRepositoryImpl(db);
    proxyRepository = ProxyRepositoryImpl(db);
    accountRepository = AccountRepositoryImpl(db);
    notificationRepository = NotificationRepositoryImpl(db);
  }

  /// Initialize the database service
  Future<DatabaseService> init() async {
    _database = AppDatabase();

    // Initialize repositories
    configRepository = ConfigRepositoryImpl(_database);
    proxyRepository = ProxyRepositoryImpl(_database);
    accountRepository = AccountRepositoryImpl(_database);
    notificationRepository = NotificationRepositoryImpl(_database);

    return this;
  }

  /// Close the database connection
  @override
  void onClose() {
    _database.close();
    super.onClose();
  }

  /// Get the underlying database (for advanced queries)
  AppDatabase get database => _database;
}
