import 'package:mocktail/mocktail.dart';
import 'package:command_center/config/services/webshare/webshare_service.dart';
import 'package:command_center/config/services/webshare/webshare_api_client.dart';
import 'package:command_center/config/services/ipqs/ipqs_service.dart';
import 'package:command_center/config/services/ipqs/ipqs_api_client.dart';
import 'package:command_center/config/services/app_config_service.dart';
import 'package:command_center/config/services/automation/python_runner.dart';
import 'package:command_center/config/services/automation/result_parser.dart';
import 'package:command_center/config/services/native_commands_service.dart';
import 'package:command_center/domain/repositories/proxy_repository.dart';
import 'package:command_center/domain/repositories/account_repository.dart';
import 'package:command_center/domain/repositories/config_repository.dart';

class MockWebshareService extends Mock implements WebshareService {}

class MockWebshareApiClient extends Mock implements WebshareApiClient {}

class MockIpqsService extends Mock implements IpqsService {}

class MockIpqsApiClient extends Mock implements IpqsApiClient {}

class MockAppConfigService extends Mock implements AppConfigService {}

class MockProxyRepository extends Mock implements ProxyRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

class MockConfigRepository extends Mock implements ConfigRepository {}

class MockNativeCommandsService extends Mock
    implements NativeCommandsService {}
