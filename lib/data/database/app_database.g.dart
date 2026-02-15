// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppConfigTableTable extends AppConfigTable
    with TableInfo<$AppConfigTableTable, AppConfigTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppConfigTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [key, value, createdAt, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_config_table';
  @override
  VerificationContext validateIntegrity(Insertable<AppConfigTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppConfigTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppConfigTableData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $AppConfigTableTable createAlias(String alias) {
    return $AppConfigTableTable(attachedDatabase, alias);
  }
}

class AppConfigTableData extends DataClass
    implements Insertable<AppConfigTableData> {
  /// The configuration key (unique identifier)
  final String key;

  /// The configuration value (stored as JSON string for complex types)
  final String value;

  /// When this config entry was created
  final DateTime createdAt;

  /// When this config entry was last updated
  final DateTime lastUpdated;
  const AppConfigTableData(
      {required this.key,
      required this.value,
      required this.createdAt,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  AppConfigTableCompanion toCompanion(bool nullToAbsent) {
    return AppConfigTableCompanion(
      key: Value(key),
      value: Value(value),
      createdAt: Value(createdAt),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory AppConfigTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppConfigTableData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  AppConfigTableData copyWith(
          {String? key,
          String? value,
          DateTime? createdAt,
          DateTime? lastUpdated}) =>
      AppConfigTableData(
        key: key ?? this.key,
        value: value ?? this.value,
        createdAt: createdAt ?? this.createdAt,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  AppConfigTableData copyWithCompanion(AppConfigTableCompanion data) {
    return AppConfigTableData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppConfigTableData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, createdAt, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppConfigTableData &&
          other.key == this.key &&
          other.value == this.value &&
          other.createdAt == this.createdAt &&
          other.lastUpdated == this.lastUpdated);
}

class AppConfigTableCompanion extends UpdateCompanion<AppConfigTableData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUpdated;
  final Value<int> rowid;
  const AppConfigTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppConfigTableCompanion.insert({
    required String key,
    required String value,
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppConfigTableData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppConfigTableCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastUpdated,
      Value<int>? rowid}) {
    return AppConfigTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppConfigTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProxySlotsTableTable extends ProxySlotsTable
    with TableInfo<$ProxySlotsTableTable, ProxySlotsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProxySlotsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _webshareIdMeta =
      const VerificationMeta('webshareId');
  @override
  late final GeneratedColumn<String> webshareId = GeneratedColumn<String>(
      'webshare_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _slotNameMeta =
      const VerificationMeta('slotName');
  @override
  late final GeneratedColumn<String> slotName = GeneratedColumn<String>(
      'slot_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _slotNumberMeta =
      const VerificationMeta('slotNumber');
  @override
  late final GeneratedColumn<int> slotNumber = GeneratedColumn<int>(
      'slot_number', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _currentIpAddressIdMeta =
      const VerificationMeta('currentIpAddressId');
  @override
  late final GeneratedColumn<int> currentIpAddressId = GeneratedColumn<int>(
      'current_ip_address_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _passwordMeta =
      const VerificationMeta('password');
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
      'password', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
      'port', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _totalIpChangesMeta =
      const VerificationMeta('totalIpChanges');
  @override
  late final GeneratedColumn<int> totalIpChanges = GeneratedColumn<int>(
      'total_ip_changes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        webshareId,
        slotName,
        slotNumber,
        currentIpAddressId,
        username,
        password,
        port,
        createdAt,
        lastUpdated,
        totalIpChanges,
        isActive
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'proxy_slots_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ProxySlotsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('webshare_id')) {
      context.handle(
          _webshareIdMeta,
          webshareId.isAcceptableOrUnknown(
              data['webshare_id']!, _webshareIdMeta));
    } else if (isInserting) {
      context.missing(_webshareIdMeta);
    }
    if (data.containsKey('slot_name')) {
      context.handle(_slotNameMeta,
          slotName.isAcceptableOrUnknown(data['slot_name']!, _slotNameMeta));
    }
    if (data.containsKey('slot_number')) {
      context.handle(
          _slotNumberMeta,
          slotNumber.isAcceptableOrUnknown(
              data['slot_number']!, _slotNumberMeta));
    } else if (isInserting) {
      context.missing(_slotNumberMeta);
    }
    if (data.containsKey('current_ip_address_id')) {
      context.handle(
          _currentIpAddressIdMeta,
          currentIpAddressId.isAcceptableOrUnknown(
              data['current_ip_address_id']!, _currentIpAddressIdMeta));
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('password')) {
      context.handle(_passwordMeta,
          password.isAcceptableOrUnknown(data['password']!, _passwordMeta));
    } else if (isInserting) {
      context.missing(_passwordMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
          _portMeta, port.isAcceptableOrUnknown(data['port']!, _portMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    }
    if (data.containsKey('total_ip_changes')) {
      context.handle(
          _totalIpChangesMeta,
          totalIpChanges.isAcceptableOrUnknown(
              data['total_ip_changes']!, _totalIpChangesMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProxySlotsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProxySlotsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      webshareId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}webshare_id'])!,
      slotName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}slot_name'])!,
      slotNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}slot_number'])!,
      currentIpAddressId: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}current_ip_address_id']),
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username'])!,
      password: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password'])!,
      port: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}port'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
      totalIpChanges: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_ip_changes'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $ProxySlotsTableTable createAlias(String alias) {
    return $ProxySlotsTableTable(attachedDatabase, alias);
  }
}

class ProxySlotsTableData extends DataClass
    implements Insertable<ProxySlotsTableData> {
  /// Auto-increment primary key
  final int id;

  /// Webshare proxy ID (unique)
  final String webshareId;

  /// Slot name/label
  final String slotName;

  /// Slot number (unique, used for ordering)
  final int slotNumber;

  /// Reference to the current active IP address (nullable)
  final int? currentIpAddressId;

  /// Proxy username
  final String username;

  /// Proxy password
  final String password;

  /// Proxy port
  final int port;

  /// When this slot was first created
  final DateTime createdAt;

  /// When this slot was last updated
  final DateTime lastUpdated;

  /// Total number of IP changes for this slot
  final int totalIpChanges;

  /// Whether this slot is active
  final bool isActive;
  const ProxySlotsTableData(
      {required this.id,
      required this.webshareId,
      required this.slotName,
      required this.slotNumber,
      this.currentIpAddressId,
      required this.username,
      required this.password,
      required this.port,
      required this.createdAt,
      required this.lastUpdated,
      required this.totalIpChanges,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['webshare_id'] = Variable<String>(webshareId);
    map['slot_name'] = Variable<String>(slotName);
    map['slot_number'] = Variable<int>(slotNumber);
    if (!nullToAbsent || currentIpAddressId != null) {
      map['current_ip_address_id'] = Variable<int>(currentIpAddressId);
    }
    map['username'] = Variable<String>(username);
    map['password'] = Variable<String>(password);
    map['port'] = Variable<int>(port);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    map['total_ip_changes'] = Variable<int>(totalIpChanges);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ProxySlotsTableCompanion toCompanion(bool nullToAbsent) {
    return ProxySlotsTableCompanion(
      id: Value(id),
      webshareId: Value(webshareId),
      slotName: Value(slotName),
      slotNumber: Value(slotNumber),
      currentIpAddressId: currentIpAddressId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentIpAddressId),
      username: Value(username),
      password: Value(password),
      port: Value(port),
      createdAt: Value(createdAt),
      lastUpdated: Value(lastUpdated),
      totalIpChanges: Value(totalIpChanges),
      isActive: Value(isActive),
    );
  }

  factory ProxySlotsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProxySlotsTableData(
      id: serializer.fromJson<int>(json['id']),
      webshareId: serializer.fromJson<String>(json['webshareId']),
      slotName: serializer.fromJson<String>(json['slotName']),
      slotNumber: serializer.fromJson<int>(json['slotNumber']),
      currentIpAddressId: serializer.fromJson<int?>(json['currentIpAddressId']),
      username: serializer.fromJson<String>(json['username']),
      password: serializer.fromJson<String>(json['password']),
      port: serializer.fromJson<int>(json['port']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
      totalIpChanges: serializer.fromJson<int>(json['totalIpChanges']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'webshareId': serializer.toJson<String>(webshareId),
      'slotName': serializer.toJson<String>(slotName),
      'slotNumber': serializer.toJson<int>(slotNumber),
      'currentIpAddressId': serializer.toJson<int?>(currentIpAddressId),
      'username': serializer.toJson<String>(username),
      'password': serializer.toJson<String>(password),
      'port': serializer.toJson<int>(port),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
      'totalIpChanges': serializer.toJson<int>(totalIpChanges),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  ProxySlotsTableData copyWith(
          {int? id,
          String? webshareId,
          String? slotName,
          int? slotNumber,
          Value<int?> currentIpAddressId = const Value.absent(),
          String? username,
          String? password,
          int? port,
          DateTime? createdAt,
          DateTime? lastUpdated,
          int? totalIpChanges,
          bool? isActive}) =>
      ProxySlotsTableData(
        id: id ?? this.id,
        webshareId: webshareId ?? this.webshareId,
        slotName: slotName ?? this.slotName,
        slotNumber: slotNumber ?? this.slotNumber,
        currentIpAddressId: currentIpAddressId.present
            ? currentIpAddressId.value
            : this.currentIpAddressId,
        username: username ?? this.username,
        password: password ?? this.password,
        port: port ?? this.port,
        createdAt: createdAt ?? this.createdAt,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        totalIpChanges: totalIpChanges ?? this.totalIpChanges,
        isActive: isActive ?? this.isActive,
      );
  ProxySlotsTableData copyWithCompanion(ProxySlotsTableCompanion data) {
    return ProxySlotsTableData(
      id: data.id.present ? data.id.value : this.id,
      webshareId:
          data.webshareId.present ? data.webshareId.value : this.webshareId,
      slotName: data.slotName.present ? data.slotName.value : this.slotName,
      slotNumber:
          data.slotNumber.present ? data.slotNumber.value : this.slotNumber,
      currentIpAddressId: data.currentIpAddressId.present
          ? data.currentIpAddressId.value
          : this.currentIpAddressId,
      username: data.username.present ? data.username.value : this.username,
      password: data.password.present ? data.password.value : this.password,
      port: data.port.present ? data.port.value : this.port,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
      totalIpChanges: data.totalIpChanges.present
          ? data.totalIpChanges.value
          : this.totalIpChanges,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProxySlotsTableData(')
          ..write('id: $id, ')
          ..write('webshareId: $webshareId, ')
          ..write('slotName: $slotName, ')
          ..write('slotNumber: $slotNumber, ')
          ..write('currentIpAddressId: $currentIpAddressId, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('port: $port, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('totalIpChanges: $totalIpChanges, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      webshareId,
      slotName,
      slotNumber,
      currentIpAddressId,
      username,
      password,
      port,
      createdAt,
      lastUpdated,
      totalIpChanges,
      isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProxySlotsTableData &&
          other.id == this.id &&
          other.webshareId == this.webshareId &&
          other.slotName == this.slotName &&
          other.slotNumber == this.slotNumber &&
          other.currentIpAddressId == this.currentIpAddressId &&
          other.username == this.username &&
          other.password == this.password &&
          other.port == this.port &&
          other.createdAt == this.createdAt &&
          other.lastUpdated == this.lastUpdated &&
          other.totalIpChanges == this.totalIpChanges &&
          other.isActive == this.isActive);
}

class ProxySlotsTableCompanion extends UpdateCompanion<ProxySlotsTableData> {
  final Value<int> id;
  final Value<String> webshareId;
  final Value<String> slotName;
  final Value<int> slotNumber;
  final Value<int?> currentIpAddressId;
  final Value<String> username;
  final Value<String> password;
  final Value<int> port;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUpdated;
  final Value<int> totalIpChanges;
  final Value<bool> isActive;
  const ProxySlotsTableCompanion({
    this.id = const Value.absent(),
    this.webshareId = const Value.absent(),
    this.slotName = const Value.absent(),
    this.slotNumber = const Value.absent(),
    this.currentIpAddressId = const Value.absent(),
    this.username = const Value.absent(),
    this.password = const Value.absent(),
    this.port = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.totalIpChanges = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  ProxySlotsTableCompanion.insert({
    this.id = const Value.absent(),
    required String webshareId,
    this.slotName = const Value.absent(),
    required int slotNumber,
    this.currentIpAddressId = const Value.absent(),
    required String username,
    required String password,
    this.port = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.totalIpChanges = const Value.absent(),
    this.isActive = const Value.absent(),
  })  : webshareId = Value(webshareId),
        slotNumber = Value(slotNumber),
        username = Value(username),
        password = Value(password);
  static Insertable<ProxySlotsTableData> custom({
    Expression<int>? id,
    Expression<String>? webshareId,
    Expression<String>? slotName,
    Expression<int>? slotNumber,
    Expression<int>? currentIpAddressId,
    Expression<String>? username,
    Expression<String>? password,
    Expression<int>? port,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUpdated,
    Expression<int>? totalIpChanges,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (webshareId != null) 'webshare_id': webshareId,
      if (slotName != null) 'slot_name': slotName,
      if (slotNumber != null) 'slot_number': slotNumber,
      if (currentIpAddressId != null)
        'current_ip_address_id': currentIpAddressId,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (port != null) 'port': port,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (totalIpChanges != null) 'total_ip_changes': totalIpChanges,
      if (isActive != null) 'is_active': isActive,
    });
  }

  ProxySlotsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? webshareId,
      Value<String>? slotName,
      Value<int>? slotNumber,
      Value<int?>? currentIpAddressId,
      Value<String>? username,
      Value<String>? password,
      Value<int>? port,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastUpdated,
      Value<int>? totalIpChanges,
      Value<bool>? isActive}) {
    return ProxySlotsTableCompanion(
      id: id ?? this.id,
      webshareId: webshareId ?? this.webshareId,
      slotName: slotName ?? this.slotName,
      slotNumber: slotNumber ?? this.slotNumber,
      currentIpAddressId: currentIpAddressId ?? this.currentIpAddressId,
      username: username ?? this.username,
      password: password ?? this.password,
      port: port ?? this.port,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      totalIpChanges: totalIpChanges ?? this.totalIpChanges,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (webshareId.present) {
      map['webshare_id'] = Variable<String>(webshareId.value);
    }
    if (slotName.present) {
      map['slot_name'] = Variable<String>(slotName.value);
    }
    if (slotNumber.present) {
      map['slot_number'] = Variable<int>(slotNumber.value);
    }
    if (currentIpAddressId.present) {
      map['current_ip_address_id'] = Variable<int>(currentIpAddressId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (totalIpChanges.present) {
      map['total_ip_changes'] = Variable<int>(totalIpChanges.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProxySlotsTableCompanion(')
          ..write('id: $id, ')
          ..write('webshareId: $webshareId, ')
          ..write('slotName: $slotName, ')
          ..write('slotNumber: $slotNumber, ')
          ..write('currentIpAddressId: $currentIpAddressId, ')
          ..write('username: $username, ')
          ..write('password: $password, ')
          ..write('port: $port, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('totalIpChanges: $totalIpChanges, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $ProxyIpAddressesTableTable extends ProxyIpAddressesTable
    with TableInfo<$ProxyIpAddressesTableTable, ProxyIpAddressesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProxyIpAddressesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _ipAddressMeta =
      const VerificationMeta('ipAddress');
  @override
  late final GeneratedColumn<String> ipAddress = GeneratedColumn<String>(
      'ip_address', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hostnameMeta =
      const VerificationMeta('hostname');
  @override
  late final GeneratedColumn<String> hostname = GeneratedColumn<String>(
      'hostname', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _slotIdMeta = const VerificationMeta('slotId');
  @override
  late final GeneratedColumn<int> slotId = GeneratedColumn<int>(
      'slot_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES proxy_slots_table (id)'));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _countryCodeMeta =
      const VerificationMeta('countryCode');
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
      'country_code', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('XX'));
  static const VerificationMeta _cityNameMeta =
      const VerificationMeta('cityName');
  @override
  late final GeneratedColumn<String> cityName = GeneratedColumn<String>(
      'city_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _ipTimezoneMeta =
      const VerificationMeta('ipTimezone');
  @override
  late final GeneratedColumn<String> ipTimezone = GeneratedColumn<String>(
      'ip_timezone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('UTC'));
  static const VerificationMeta _highCountryConfidenceMeta =
      const VerificationMeta('highCountryConfidence');
  @override
  late final GeneratedColumn<bool> highCountryConfidence =
      GeneratedColumn<bool>('high_country_confidence', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("high_country_confidence" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _asnNameMeta =
      const VerificationMeta('asnName');
  @override
  late final GeneratedColumn<String> asnName = GeneratedColumn<String>(
      'asn_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _asnNumberMeta =
      const VerificationMeta('asnNumber');
  @override
  late final GeneratedColumn<int> asnNumber = GeneratedColumn<int>(
      'asn_number', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _ipScoreMeta =
      const VerificationMeta('ipScore');
  @override
  late final GeneratedColumn<double> ipScore = GeneratedColumn<double>(
      'ip_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _scoreLevelMeta =
      const VerificationMeta('scoreLevel');
  @override
  late final GeneratedColumn<String> scoreLevel = GeneratedColumn<String>(
      'score_level', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('unknown'));
  static const VerificationMeta _isVpnMeta = const VerificationMeta('isVpn');
  @override
  late final GeneratedColumn<bool> isVpn = GeneratedColumn<bool>(
      'is_vpn', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_vpn" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isProxyMeta =
      const VerificationMeta('isProxy');
  @override
  late final GeneratedColumn<bool> isProxy = GeneratedColumn<bool>(
      'is_proxy', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_proxy" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _isDatacenterMeta =
      const VerificationMeta('isDatacenter');
  @override
  late final GeneratedColumn<bool> isDatacenter = GeneratedColumn<bool>(
      'is_datacenter', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_datacenter" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isTorMeta = const VerificationMeta('isTor');
  @override
  late final GeneratedColumn<bool> isTor = GeneratedColumn<bool>(
      'is_tor', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_tor" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _fraudScoreMeta =
      const VerificationMeta('fraudScore');
  @override
  late final GeneratedColumn<double> fraudScore = GeneratedColumn<double>(
      'fraud_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _abuseConfidenceMeta =
      const VerificationMeta('abuseConfidence');
  @override
  late final GeneratedColumn<int> abuseConfidence = GeneratedColumn<int>(
      'abuse_confidence', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _assignedAtMeta =
      const VerificationMeta('assignedAt');
  @override
  late final GeneratedColumn<DateTime> assignedAt = GeneratedColumn<DateTime>(
      'assigned_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _removedAtMeta =
      const VerificationMeta('removedAt');
  @override
  late final GeneratedColumn<DateTime> removedAt = GeneratedColumn<DateTime>(
      'removed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastVerificationMeta =
      const VerificationMeta('lastVerification');
  @override
  late final GeneratedColumn<DateTime> lastVerification =
      GeneratedColumn<DateTime>('last_verification', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  static const VerificationMeta _lastScoreCheckMeta =
      const VerificationMeta('lastScoreCheck');
  @override
  late final GeneratedColumn<DateTime> lastScoreCheck =
      GeneratedColumn<DateTime>('last_score_check', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _totalDaysUsedMeta =
      const VerificationMeta('totalDaysUsed');
  @override
  late final GeneratedColumn<int> totalDaysUsed = GeneratedColumn<int>(
      'total_days_used', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _timesAssignedMeta =
      const VerificationMeta('timesAssigned');
  @override
  late final GeneratedColumn<int> timesAssigned = GeneratedColumn<int>(
      'times_assigned', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        ipAddress,
        hostname,
        slotId,
        isActive,
        countryCode,
        cityName,
        ipTimezone,
        highCountryConfidence,
        asnName,
        asnNumber,
        ipScore,
        scoreLevel,
        isVpn,
        isProxy,
        isDatacenter,
        isTor,
        fraudScore,
        abuseConfidence,
        assignedAt,
        removedAt,
        lastVerification,
        lastScoreCheck,
        totalDaysUsed,
        timesAssigned
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'proxy_ip_addresses_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ProxyIpAddressesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ip_address')) {
      context.handle(_ipAddressMeta,
          ipAddress.isAcceptableOrUnknown(data['ip_address']!, _ipAddressMeta));
    } else if (isInserting) {
      context.missing(_ipAddressMeta);
    }
    if (data.containsKey('hostname')) {
      context.handle(_hostnameMeta,
          hostname.isAcceptableOrUnknown(data['hostname']!, _hostnameMeta));
    }
    if (data.containsKey('slot_id')) {
      context.handle(_slotIdMeta,
          slotId.isAcceptableOrUnknown(data['slot_id']!, _slotIdMeta));
    } else if (isInserting) {
      context.missing(_slotIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('country_code')) {
      context.handle(
          _countryCodeMeta,
          countryCode.isAcceptableOrUnknown(
              data['country_code']!, _countryCodeMeta));
    }
    if (data.containsKey('city_name')) {
      context.handle(_cityNameMeta,
          cityName.isAcceptableOrUnknown(data['city_name']!, _cityNameMeta));
    }
    if (data.containsKey('ip_timezone')) {
      context.handle(
          _ipTimezoneMeta,
          ipTimezone.isAcceptableOrUnknown(
              data['ip_timezone']!, _ipTimezoneMeta));
    }
    if (data.containsKey('high_country_confidence')) {
      context.handle(
          _highCountryConfidenceMeta,
          highCountryConfidence.isAcceptableOrUnknown(
              data['high_country_confidence']!, _highCountryConfidenceMeta));
    }
    if (data.containsKey('asn_name')) {
      context.handle(_asnNameMeta,
          asnName.isAcceptableOrUnknown(data['asn_name']!, _asnNameMeta));
    }
    if (data.containsKey('asn_number')) {
      context.handle(_asnNumberMeta,
          asnNumber.isAcceptableOrUnknown(data['asn_number']!, _asnNumberMeta));
    }
    if (data.containsKey('ip_score')) {
      context.handle(_ipScoreMeta,
          ipScore.isAcceptableOrUnknown(data['ip_score']!, _ipScoreMeta));
    }
    if (data.containsKey('score_level')) {
      context.handle(
          _scoreLevelMeta,
          scoreLevel.isAcceptableOrUnknown(
              data['score_level']!, _scoreLevelMeta));
    }
    if (data.containsKey('is_vpn')) {
      context.handle(
          _isVpnMeta, isVpn.isAcceptableOrUnknown(data['is_vpn']!, _isVpnMeta));
    }
    if (data.containsKey('is_proxy')) {
      context.handle(_isProxyMeta,
          isProxy.isAcceptableOrUnknown(data['is_proxy']!, _isProxyMeta));
    }
    if (data.containsKey('is_datacenter')) {
      context.handle(
          _isDatacenterMeta,
          isDatacenter.isAcceptableOrUnknown(
              data['is_datacenter']!, _isDatacenterMeta));
    }
    if (data.containsKey('is_tor')) {
      context.handle(
          _isTorMeta, isTor.isAcceptableOrUnknown(data['is_tor']!, _isTorMeta));
    }
    if (data.containsKey('fraud_score')) {
      context.handle(
          _fraudScoreMeta,
          fraudScore.isAcceptableOrUnknown(
              data['fraud_score']!, _fraudScoreMeta));
    }
    if (data.containsKey('abuse_confidence')) {
      context.handle(
          _abuseConfidenceMeta,
          abuseConfidence.isAcceptableOrUnknown(
              data['abuse_confidence']!, _abuseConfidenceMeta));
    }
    if (data.containsKey('assigned_at')) {
      context.handle(
          _assignedAtMeta,
          assignedAt.isAcceptableOrUnknown(
              data['assigned_at']!, _assignedAtMeta));
    }
    if (data.containsKey('removed_at')) {
      context.handle(_removedAtMeta,
          removedAt.isAcceptableOrUnknown(data['removed_at']!, _removedAtMeta));
    }
    if (data.containsKey('last_verification')) {
      context.handle(
          _lastVerificationMeta,
          lastVerification.isAcceptableOrUnknown(
              data['last_verification']!, _lastVerificationMeta));
    }
    if (data.containsKey('last_score_check')) {
      context.handle(
          _lastScoreCheckMeta,
          lastScoreCheck.isAcceptableOrUnknown(
              data['last_score_check']!, _lastScoreCheckMeta));
    }
    if (data.containsKey('total_days_used')) {
      context.handle(
          _totalDaysUsedMeta,
          totalDaysUsed.isAcceptableOrUnknown(
              data['total_days_used']!, _totalDaysUsedMeta));
    }
    if (data.containsKey('times_assigned')) {
      context.handle(
          _timesAssignedMeta,
          timesAssigned.isAcceptableOrUnknown(
              data['times_assigned']!, _timesAssignedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProxyIpAddressesTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProxyIpAddressesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      ipAddress: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ip_address'])!,
      hostname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hostname'])!,
      slotId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}slot_id'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      countryCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}country_code'])!,
      cityName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city_name'])!,
      ipTimezone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ip_timezone'])!,
      highCountryConfidence: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}high_country_confidence'])!,
      asnName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}asn_name'])!,
      asnNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}asn_number'])!,
      ipScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ip_score'])!,
      scoreLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}score_level'])!,
      isVpn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_vpn'])!,
      isProxy: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_proxy'])!,
      isDatacenter: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_datacenter'])!,
      isTor: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_tor'])!,
      fraudScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}fraud_score'])!,
      abuseConfidence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}abuse_confidence'])!,
      assignedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}assigned_at'])!,
      removedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}removed_at']),
      lastVerification: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_verification'])!,
      lastScoreCheck: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_score_check']),
      totalDaysUsed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_days_used'])!,
      timesAssigned: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}times_assigned'])!,
    );
  }

  @override
  $ProxyIpAddressesTableTable createAlias(String alias) {
    return $ProxyIpAddressesTableTable(attachedDatabase, alias);
  }
}

class ProxyIpAddressesTableData extends DataClass
    implements Insertable<ProxyIpAddressesTableData> {
  /// Auto-increment primary key
  final int id;

  /// The IP address
  final String ipAddress;

  /// The hostname
  final String hostname;

  /// Reference to the proxy slot this IP belongs to
  final int slotId;

  /// Whether this IP is currently active for its slot
  final bool isActive;

  /// Country code (e.g., 'US', 'UK')
  final String countryCode;

  /// City name
  final String cityName;

  /// IP timezone
  final String ipTimezone;

  /// Whether country detection has high confidence
  final bool highCountryConfidence;

  /// ASN name (e.g., 'Comcast')
  final String asnName;

  /// ASN number
  final int asnNumber;

  /// IP quality score (0-100)
  final double ipScore;

  /// Score level: excellent, good, fair, poor, bad, unknown
  final String scoreLevel;

  /// Whether detected as VPN
  final bool isVpn;

  /// Whether detected as proxy
  final bool isProxy;

  /// Whether detected as datacenter IP
  final bool isDatacenter;

  /// Whether detected as TOR exit node
  final bool isTor;

  /// Fraud score from IP quality service
  final double fraudScore;

  /// Abuse confidence percentage (0-100)
  final int abuseConfidence;

  /// When this IP was assigned to the slot
  final DateTime assignedAt;

  /// When this IP was removed/replaced (null if still active)
  final DateTime? removedAt;

  /// Last verification timestamp
  final DateTime lastVerification;

  /// Last IP score check timestamp
  final DateTime? lastScoreCheck;

  /// Total days this IP has been used
  final int totalDaysUsed;

  /// Number of times this IP has been assigned
  final int timesAssigned;
  const ProxyIpAddressesTableData(
      {required this.id,
      required this.ipAddress,
      required this.hostname,
      required this.slotId,
      required this.isActive,
      required this.countryCode,
      required this.cityName,
      required this.ipTimezone,
      required this.highCountryConfidence,
      required this.asnName,
      required this.asnNumber,
      required this.ipScore,
      required this.scoreLevel,
      required this.isVpn,
      required this.isProxy,
      required this.isDatacenter,
      required this.isTor,
      required this.fraudScore,
      required this.abuseConfidence,
      required this.assignedAt,
      this.removedAt,
      required this.lastVerification,
      this.lastScoreCheck,
      required this.totalDaysUsed,
      required this.timesAssigned});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ip_address'] = Variable<String>(ipAddress);
    map['hostname'] = Variable<String>(hostname);
    map['slot_id'] = Variable<int>(slotId);
    map['is_active'] = Variable<bool>(isActive);
    map['country_code'] = Variable<String>(countryCode);
    map['city_name'] = Variable<String>(cityName);
    map['ip_timezone'] = Variable<String>(ipTimezone);
    map['high_country_confidence'] = Variable<bool>(highCountryConfidence);
    map['asn_name'] = Variable<String>(asnName);
    map['asn_number'] = Variable<int>(asnNumber);
    map['ip_score'] = Variable<double>(ipScore);
    map['score_level'] = Variable<String>(scoreLevel);
    map['is_vpn'] = Variable<bool>(isVpn);
    map['is_proxy'] = Variable<bool>(isProxy);
    map['is_datacenter'] = Variable<bool>(isDatacenter);
    map['is_tor'] = Variable<bool>(isTor);
    map['fraud_score'] = Variable<double>(fraudScore);
    map['abuse_confidence'] = Variable<int>(abuseConfidence);
    map['assigned_at'] = Variable<DateTime>(assignedAt);
    if (!nullToAbsent || removedAt != null) {
      map['removed_at'] = Variable<DateTime>(removedAt);
    }
    map['last_verification'] = Variable<DateTime>(lastVerification);
    if (!nullToAbsent || lastScoreCheck != null) {
      map['last_score_check'] = Variable<DateTime>(lastScoreCheck);
    }
    map['total_days_used'] = Variable<int>(totalDaysUsed);
    map['times_assigned'] = Variable<int>(timesAssigned);
    return map;
  }

  ProxyIpAddressesTableCompanion toCompanion(bool nullToAbsent) {
    return ProxyIpAddressesTableCompanion(
      id: Value(id),
      ipAddress: Value(ipAddress),
      hostname: Value(hostname),
      slotId: Value(slotId),
      isActive: Value(isActive),
      countryCode: Value(countryCode),
      cityName: Value(cityName),
      ipTimezone: Value(ipTimezone),
      highCountryConfidence: Value(highCountryConfidence),
      asnName: Value(asnName),
      asnNumber: Value(asnNumber),
      ipScore: Value(ipScore),
      scoreLevel: Value(scoreLevel),
      isVpn: Value(isVpn),
      isProxy: Value(isProxy),
      isDatacenter: Value(isDatacenter),
      isTor: Value(isTor),
      fraudScore: Value(fraudScore),
      abuseConfidence: Value(abuseConfidence),
      assignedAt: Value(assignedAt),
      removedAt: removedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(removedAt),
      lastVerification: Value(lastVerification),
      lastScoreCheck: lastScoreCheck == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScoreCheck),
      totalDaysUsed: Value(totalDaysUsed),
      timesAssigned: Value(timesAssigned),
    );
  }

  factory ProxyIpAddressesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProxyIpAddressesTableData(
      id: serializer.fromJson<int>(json['id']),
      ipAddress: serializer.fromJson<String>(json['ipAddress']),
      hostname: serializer.fromJson<String>(json['hostname']),
      slotId: serializer.fromJson<int>(json['slotId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      countryCode: serializer.fromJson<String>(json['countryCode']),
      cityName: serializer.fromJson<String>(json['cityName']),
      ipTimezone: serializer.fromJson<String>(json['ipTimezone']),
      highCountryConfidence:
          serializer.fromJson<bool>(json['highCountryConfidence']),
      asnName: serializer.fromJson<String>(json['asnName']),
      asnNumber: serializer.fromJson<int>(json['asnNumber']),
      ipScore: serializer.fromJson<double>(json['ipScore']),
      scoreLevel: serializer.fromJson<String>(json['scoreLevel']),
      isVpn: serializer.fromJson<bool>(json['isVpn']),
      isProxy: serializer.fromJson<bool>(json['isProxy']),
      isDatacenter: serializer.fromJson<bool>(json['isDatacenter']),
      isTor: serializer.fromJson<bool>(json['isTor']),
      fraudScore: serializer.fromJson<double>(json['fraudScore']),
      abuseConfidence: serializer.fromJson<int>(json['abuseConfidence']),
      assignedAt: serializer.fromJson<DateTime>(json['assignedAt']),
      removedAt: serializer.fromJson<DateTime?>(json['removedAt']),
      lastVerification: serializer.fromJson<DateTime>(json['lastVerification']),
      lastScoreCheck: serializer.fromJson<DateTime?>(json['lastScoreCheck']),
      totalDaysUsed: serializer.fromJson<int>(json['totalDaysUsed']),
      timesAssigned: serializer.fromJson<int>(json['timesAssigned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ipAddress': serializer.toJson<String>(ipAddress),
      'hostname': serializer.toJson<String>(hostname),
      'slotId': serializer.toJson<int>(slotId),
      'isActive': serializer.toJson<bool>(isActive),
      'countryCode': serializer.toJson<String>(countryCode),
      'cityName': serializer.toJson<String>(cityName),
      'ipTimezone': serializer.toJson<String>(ipTimezone),
      'highCountryConfidence': serializer.toJson<bool>(highCountryConfidence),
      'asnName': serializer.toJson<String>(asnName),
      'asnNumber': serializer.toJson<int>(asnNumber),
      'ipScore': serializer.toJson<double>(ipScore),
      'scoreLevel': serializer.toJson<String>(scoreLevel),
      'isVpn': serializer.toJson<bool>(isVpn),
      'isProxy': serializer.toJson<bool>(isProxy),
      'isDatacenter': serializer.toJson<bool>(isDatacenter),
      'isTor': serializer.toJson<bool>(isTor),
      'fraudScore': serializer.toJson<double>(fraudScore),
      'abuseConfidence': serializer.toJson<int>(abuseConfidence),
      'assignedAt': serializer.toJson<DateTime>(assignedAt),
      'removedAt': serializer.toJson<DateTime?>(removedAt),
      'lastVerification': serializer.toJson<DateTime>(lastVerification),
      'lastScoreCheck': serializer.toJson<DateTime?>(lastScoreCheck),
      'totalDaysUsed': serializer.toJson<int>(totalDaysUsed),
      'timesAssigned': serializer.toJson<int>(timesAssigned),
    };
  }

  ProxyIpAddressesTableData copyWith(
          {int? id,
          String? ipAddress,
          String? hostname,
          int? slotId,
          bool? isActive,
          String? countryCode,
          String? cityName,
          String? ipTimezone,
          bool? highCountryConfidence,
          String? asnName,
          int? asnNumber,
          double? ipScore,
          String? scoreLevel,
          bool? isVpn,
          bool? isProxy,
          bool? isDatacenter,
          bool? isTor,
          double? fraudScore,
          int? abuseConfidence,
          DateTime? assignedAt,
          Value<DateTime?> removedAt = const Value.absent(),
          DateTime? lastVerification,
          Value<DateTime?> lastScoreCheck = const Value.absent(),
          int? totalDaysUsed,
          int? timesAssigned}) =>
      ProxyIpAddressesTableData(
        id: id ?? this.id,
        ipAddress: ipAddress ?? this.ipAddress,
        hostname: hostname ?? this.hostname,
        slotId: slotId ?? this.slotId,
        isActive: isActive ?? this.isActive,
        countryCode: countryCode ?? this.countryCode,
        cityName: cityName ?? this.cityName,
        ipTimezone: ipTimezone ?? this.ipTimezone,
        highCountryConfidence:
            highCountryConfidence ?? this.highCountryConfidence,
        asnName: asnName ?? this.asnName,
        asnNumber: asnNumber ?? this.asnNumber,
        ipScore: ipScore ?? this.ipScore,
        scoreLevel: scoreLevel ?? this.scoreLevel,
        isVpn: isVpn ?? this.isVpn,
        isProxy: isProxy ?? this.isProxy,
        isDatacenter: isDatacenter ?? this.isDatacenter,
        isTor: isTor ?? this.isTor,
        fraudScore: fraudScore ?? this.fraudScore,
        abuseConfidence: abuseConfidence ?? this.abuseConfidence,
        assignedAt: assignedAt ?? this.assignedAt,
        removedAt: removedAt.present ? removedAt.value : this.removedAt,
        lastVerification: lastVerification ?? this.lastVerification,
        lastScoreCheck:
            lastScoreCheck.present ? lastScoreCheck.value : this.lastScoreCheck,
        totalDaysUsed: totalDaysUsed ?? this.totalDaysUsed,
        timesAssigned: timesAssigned ?? this.timesAssigned,
      );
  ProxyIpAddressesTableData copyWithCompanion(
      ProxyIpAddressesTableCompanion data) {
    return ProxyIpAddressesTableData(
      id: data.id.present ? data.id.value : this.id,
      ipAddress: data.ipAddress.present ? data.ipAddress.value : this.ipAddress,
      hostname: data.hostname.present ? data.hostname.value : this.hostname,
      slotId: data.slotId.present ? data.slotId.value : this.slotId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      countryCode:
          data.countryCode.present ? data.countryCode.value : this.countryCode,
      cityName: data.cityName.present ? data.cityName.value : this.cityName,
      ipTimezone:
          data.ipTimezone.present ? data.ipTimezone.value : this.ipTimezone,
      highCountryConfidence: data.highCountryConfidence.present
          ? data.highCountryConfidence.value
          : this.highCountryConfidence,
      asnName: data.asnName.present ? data.asnName.value : this.asnName,
      asnNumber: data.asnNumber.present ? data.asnNumber.value : this.asnNumber,
      ipScore: data.ipScore.present ? data.ipScore.value : this.ipScore,
      scoreLevel:
          data.scoreLevel.present ? data.scoreLevel.value : this.scoreLevel,
      isVpn: data.isVpn.present ? data.isVpn.value : this.isVpn,
      isProxy: data.isProxy.present ? data.isProxy.value : this.isProxy,
      isDatacenter: data.isDatacenter.present
          ? data.isDatacenter.value
          : this.isDatacenter,
      isTor: data.isTor.present ? data.isTor.value : this.isTor,
      fraudScore:
          data.fraudScore.present ? data.fraudScore.value : this.fraudScore,
      abuseConfidence: data.abuseConfidence.present
          ? data.abuseConfidence.value
          : this.abuseConfidence,
      assignedAt:
          data.assignedAt.present ? data.assignedAt.value : this.assignedAt,
      removedAt: data.removedAt.present ? data.removedAt.value : this.removedAt,
      lastVerification: data.lastVerification.present
          ? data.lastVerification.value
          : this.lastVerification,
      lastScoreCheck: data.lastScoreCheck.present
          ? data.lastScoreCheck.value
          : this.lastScoreCheck,
      totalDaysUsed: data.totalDaysUsed.present
          ? data.totalDaysUsed.value
          : this.totalDaysUsed,
      timesAssigned: data.timesAssigned.present
          ? data.timesAssigned.value
          : this.timesAssigned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProxyIpAddressesTableData(')
          ..write('id: $id, ')
          ..write('ipAddress: $ipAddress, ')
          ..write('hostname: $hostname, ')
          ..write('slotId: $slotId, ')
          ..write('isActive: $isActive, ')
          ..write('countryCode: $countryCode, ')
          ..write('cityName: $cityName, ')
          ..write('ipTimezone: $ipTimezone, ')
          ..write('highCountryConfidence: $highCountryConfidence, ')
          ..write('asnName: $asnName, ')
          ..write('asnNumber: $asnNumber, ')
          ..write('ipScore: $ipScore, ')
          ..write('scoreLevel: $scoreLevel, ')
          ..write('isVpn: $isVpn, ')
          ..write('isProxy: $isProxy, ')
          ..write('isDatacenter: $isDatacenter, ')
          ..write('isTor: $isTor, ')
          ..write('fraudScore: $fraudScore, ')
          ..write('abuseConfidence: $abuseConfidence, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('removedAt: $removedAt, ')
          ..write('lastVerification: $lastVerification, ')
          ..write('lastScoreCheck: $lastScoreCheck, ')
          ..write('totalDaysUsed: $totalDaysUsed, ')
          ..write('timesAssigned: $timesAssigned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        ipAddress,
        hostname,
        slotId,
        isActive,
        countryCode,
        cityName,
        ipTimezone,
        highCountryConfidence,
        asnName,
        asnNumber,
        ipScore,
        scoreLevel,
        isVpn,
        isProxy,
        isDatacenter,
        isTor,
        fraudScore,
        abuseConfidence,
        assignedAt,
        removedAt,
        lastVerification,
        lastScoreCheck,
        totalDaysUsed,
        timesAssigned
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProxyIpAddressesTableData &&
          other.id == this.id &&
          other.ipAddress == this.ipAddress &&
          other.hostname == this.hostname &&
          other.slotId == this.slotId &&
          other.isActive == this.isActive &&
          other.countryCode == this.countryCode &&
          other.cityName == this.cityName &&
          other.ipTimezone == this.ipTimezone &&
          other.highCountryConfidence == this.highCountryConfidence &&
          other.asnName == this.asnName &&
          other.asnNumber == this.asnNumber &&
          other.ipScore == this.ipScore &&
          other.scoreLevel == this.scoreLevel &&
          other.isVpn == this.isVpn &&
          other.isProxy == this.isProxy &&
          other.isDatacenter == this.isDatacenter &&
          other.isTor == this.isTor &&
          other.fraudScore == this.fraudScore &&
          other.abuseConfidence == this.abuseConfidence &&
          other.assignedAt == this.assignedAt &&
          other.removedAt == this.removedAt &&
          other.lastVerification == this.lastVerification &&
          other.lastScoreCheck == this.lastScoreCheck &&
          other.totalDaysUsed == this.totalDaysUsed &&
          other.timesAssigned == this.timesAssigned);
}

class ProxyIpAddressesTableCompanion
    extends UpdateCompanion<ProxyIpAddressesTableData> {
  final Value<int> id;
  final Value<String> ipAddress;
  final Value<String> hostname;
  final Value<int> slotId;
  final Value<bool> isActive;
  final Value<String> countryCode;
  final Value<String> cityName;
  final Value<String> ipTimezone;
  final Value<bool> highCountryConfidence;
  final Value<String> asnName;
  final Value<int> asnNumber;
  final Value<double> ipScore;
  final Value<String> scoreLevel;
  final Value<bool> isVpn;
  final Value<bool> isProxy;
  final Value<bool> isDatacenter;
  final Value<bool> isTor;
  final Value<double> fraudScore;
  final Value<int> abuseConfidence;
  final Value<DateTime> assignedAt;
  final Value<DateTime?> removedAt;
  final Value<DateTime> lastVerification;
  final Value<DateTime?> lastScoreCheck;
  final Value<int> totalDaysUsed;
  final Value<int> timesAssigned;
  const ProxyIpAddressesTableCompanion({
    this.id = const Value.absent(),
    this.ipAddress = const Value.absent(),
    this.hostname = const Value.absent(),
    this.slotId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.cityName = const Value.absent(),
    this.ipTimezone = const Value.absent(),
    this.highCountryConfidence = const Value.absent(),
    this.asnName = const Value.absent(),
    this.asnNumber = const Value.absent(),
    this.ipScore = const Value.absent(),
    this.scoreLevel = const Value.absent(),
    this.isVpn = const Value.absent(),
    this.isProxy = const Value.absent(),
    this.isDatacenter = const Value.absent(),
    this.isTor = const Value.absent(),
    this.fraudScore = const Value.absent(),
    this.abuseConfidence = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.lastVerification = const Value.absent(),
    this.lastScoreCheck = const Value.absent(),
    this.totalDaysUsed = const Value.absent(),
    this.timesAssigned = const Value.absent(),
  });
  ProxyIpAddressesTableCompanion.insert({
    this.id = const Value.absent(),
    required String ipAddress,
    this.hostname = const Value.absent(),
    required int slotId,
    this.isActive = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.cityName = const Value.absent(),
    this.ipTimezone = const Value.absent(),
    this.highCountryConfidence = const Value.absent(),
    this.asnName = const Value.absent(),
    this.asnNumber = const Value.absent(),
    this.ipScore = const Value.absent(),
    this.scoreLevel = const Value.absent(),
    this.isVpn = const Value.absent(),
    this.isProxy = const Value.absent(),
    this.isDatacenter = const Value.absent(),
    this.isTor = const Value.absent(),
    this.fraudScore = const Value.absent(),
    this.abuseConfidence = const Value.absent(),
    this.assignedAt = const Value.absent(),
    this.removedAt = const Value.absent(),
    this.lastVerification = const Value.absent(),
    this.lastScoreCheck = const Value.absent(),
    this.totalDaysUsed = const Value.absent(),
    this.timesAssigned = const Value.absent(),
  })  : ipAddress = Value(ipAddress),
        slotId = Value(slotId);
  static Insertable<ProxyIpAddressesTableData> custom({
    Expression<int>? id,
    Expression<String>? ipAddress,
    Expression<String>? hostname,
    Expression<int>? slotId,
    Expression<bool>? isActive,
    Expression<String>? countryCode,
    Expression<String>? cityName,
    Expression<String>? ipTimezone,
    Expression<bool>? highCountryConfidence,
    Expression<String>? asnName,
    Expression<int>? asnNumber,
    Expression<double>? ipScore,
    Expression<String>? scoreLevel,
    Expression<bool>? isVpn,
    Expression<bool>? isProxy,
    Expression<bool>? isDatacenter,
    Expression<bool>? isTor,
    Expression<double>? fraudScore,
    Expression<int>? abuseConfidence,
    Expression<DateTime>? assignedAt,
    Expression<DateTime>? removedAt,
    Expression<DateTime>? lastVerification,
    Expression<DateTime>? lastScoreCheck,
    Expression<int>? totalDaysUsed,
    Expression<int>? timesAssigned,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (hostname != null) 'hostname': hostname,
      if (slotId != null) 'slot_id': slotId,
      if (isActive != null) 'is_active': isActive,
      if (countryCode != null) 'country_code': countryCode,
      if (cityName != null) 'city_name': cityName,
      if (ipTimezone != null) 'ip_timezone': ipTimezone,
      if (highCountryConfidence != null)
        'high_country_confidence': highCountryConfidence,
      if (asnName != null) 'asn_name': asnName,
      if (asnNumber != null) 'asn_number': asnNumber,
      if (ipScore != null) 'ip_score': ipScore,
      if (scoreLevel != null) 'score_level': scoreLevel,
      if (isVpn != null) 'is_vpn': isVpn,
      if (isProxy != null) 'is_proxy': isProxy,
      if (isDatacenter != null) 'is_datacenter': isDatacenter,
      if (isTor != null) 'is_tor': isTor,
      if (fraudScore != null) 'fraud_score': fraudScore,
      if (abuseConfidence != null) 'abuse_confidence': abuseConfidence,
      if (assignedAt != null) 'assigned_at': assignedAt,
      if (removedAt != null) 'removed_at': removedAt,
      if (lastVerification != null) 'last_verification': lastVerification,
      if (lastScoreCheck != null) 'last_score_check': lastScoreCheck,
      if (totalDaysUsed != null) 'total_days_used': totalDaysUsed,
      if (timesAssigned != null) 'times_assigned': timesAssigned,
    });
  }

  ProxyIpAddressesTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? ipAddress,
      Value<String>? hostname,
      Value<int>? slotId,
      Value<bool>? isActive,
      Value<String>? countryCode,
      Value<String>? cityName,
      Value<String>? ipTimezone,
      Value<bool>? highCountryConfidence,
      Value<String>? asnName,
      Value<int>? asnNumber,
      Value<double>? ipScore,
      Value<String>? scoreLevel,
      Value<bool>? isVpn,
      Value<bool>? isProxy,
      Value<bool>? isDatacenter,
      Value<bool>? isTor,
      Value<double>? fraudScore,
      Value<int>? abuseConfidence,
      Value<DateTime>? assignedAt,
      Value<DateTime?>? removedAt,
      Value<DateTime>? lastVerification,
      Value<DateTime?>? lastScoreCheck,
      Value<int>? totalDaysUsed,
      Value<int>? timesAssigned}) {
    return ProxyIpAddressesTableCompanion(
      id: id ?? this.id,
      ipAddress: ipAddress ?? this.ipAddress,
      hostname: hostname ?? this.hostname,
      slotId: slotId ?? this.slotId,
      isActive: isActive ?? this.isActive,
      countryCode: countryCode ?? this.countryCode,
      cityName: cityName ?? this.cityName,
      ipTimezone: ipTimezone ?? this.ipTimezone,
      highCountryConfidence:
          highCountryConfidence ?? this.highCountryConfidence,
      asnName: asnName ?? this.asnName,
      asnNumber: asnNumber ?? this.asnNumber,
      ipScore: ipScore ?? this.ipScore,
      scoreLevel: scoreLevel ?? this.scoreLevel,
      isVpn: isVpn ?? this.isVpn,
      isProxy: isProxy ?? this.isProxy,
      isDatacenter: isDatacenter ?? this.isDatacenter,
      isTor: isTor ?? this.isTor,
      fraudScore: fraudScore ?? this.fraudScore,
      abuseConfidence: abuseConfidence ?? this.abuseConfidence,
      assignedAt: assignedAt ?? this.assignedAt,
      removedAt: removedAt ?? this.removedAt,
      lastVerification: lastVerification ?? this.lastVerification,
      lastScoreCheck: lastScoreCheck ?? this.lastScoreCheck,
      totalDaysUsed: totalDaysUsed ?? this.totalDaysUsed,
      timesAssigned: timesAssigned ?? this.timesAssigned,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ipAddress.present) {
      map['ip_address'] = Variable<String>(ipAddress.value);
    }
    if (hostname.present) {
      map['hostname'] = Variable<String>(hostname.value);
    }
    if (slotId.present) {
      map['slot_id'] = Variable<int>(slotId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (cityName.present) {
      map['city_name'] = Variable<String>(cityName.value);
    }
    if (ipTimezone.present) {
      map['ip_timezone'] = Variable<String>(ipTimezone.value);
    }
    if (highCountryConfidence.present) {
      map['high_country_confidence'] =
          Variable<bool>(highCountryConfidence.value);
    }
    if (asnName.present) {
      map['asn_name'] = Variable<String>(asnName.value);
    }
    if (asnNumber.present) {
      map['asn_number'] = Variable<int>(asnNumber.value);
    }
    if (ipScore.present) {
      map['ip_score'] = Variable<double>(ipScore.value);
    }
    if (scoreLevel.present) {
      map['score_level'] = Variable<String>(scoreLevel.value);
    }
    if (isVpn.present) {
      map['is_vpn'] = Variable<bool>(isVpn.value);
    }
    if (isProxy.present) {
      map['is_proxy'] = Variable<bool>(isProxy.value);
    }
    if (isDatacenter.present) {
      map['is_datacenter'] = Variable<bool>(isDatacenter.value);
    }
    if (isTor.present) {
      map['is_tor'] = Variable<bool>(isTor.value);
    }
    if (fraudScore.present) {
      map['fraud_score'] = Variable<double>(fraudScore.value);
    }
    if (abuseConfidence.present) {
      map['abuse_confidence'] = Variable<int>(abuseConfidence.value);
    }
    if (assignedAt.present) {
      map['assigned_at'] = Variable<DateTime>(assignedAt.value);
    }
    if (removedAt.present) {
      map['removed_at'] = Variable<DateTime>(removedAt.value);
    }
    if (lastVerification.present) {
      map['last_verification'] = Variable<DateTime>(lastVerification.value);
    }
    if (lastScoreCheck.present) {
      map['last_score_check'] = Variable<DateTime>(lastScoreCheck.value);
    }
    if (totalDaysUsed.present) {
      map['total_days_used'] = Variable<int>(totalDaysUsed.value);
    }
    if (timesAssigned.present) {
      map['times_assigned'] = Variable<int>(timesAssigned.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProxyIpAddressesTableCompanion(')
          ..write('id: $id, ')
          ..write('ipAddress: $ipAddress, ')
          ..write('hostname: $hostname, ')
          ..write('slotId: $slotId, ')
          ..write('isActive: $isActive, ')
          ..write('countryCode: $countryCode, ')
          ..write('cityName: $cityName, ')
          ..write('ipTimezone: $ipTimezone, ')
          ..write('highCountryConfidence: $highCountryConfidence, ')
          ..write('asnName: $asnName, ')
          ..write('asnNumber: $asnNumber, ')
          ..write('ipScore: $ipScore, ')
          ..write('scoreLevel: $scoreLevel, ')
          ..write('isVpn: $isVpn, ')
          ..write('isProxy: $isProxy, ')
          ..write('isDatacenter: $isDatacenter, ')
          ..write('isTor: $isTor, ')
          ..write('fraudScore: $fraudScore, ')
          ..write('abuseConfidence: $abuseConfidence, ')
          ..write('assignedAt: $assignedAt, ')
          ..write('removedAt: $removedAt, ')
          ..write('lastVerification: $lastVerification, ')
          ..write('lastScoreCheck: $lastScoreCheck, ')
          ..write('totalDaysUsed: $totalDaysUsed, ')
          ..write('timesAssigned: $timesAssigned')
          ..write(')'))
        .toString();
  }
}

class $AccountsTableTable extends AccountsTable
    with TableInfo<$AccountsTableTable, AccountsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _accountNameMeta =
      const VerificationMeta('accountName');
  @override
  late final GeneratedColumn<String> accountName = GeneratedColumn<String>(
      'account_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _birthdayMeta =
      const VerificationMeta('birthday');
  @override
  late final GeneratedColumn<String> birthday = GeneratedColumn<String>(
      'birthday', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('01-01-2000'));
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _passwordMeta =
      const VerificationMeta('password');
  @override
  late final GeneratedColumn<String> password = GeneratedColumn<String>(
      'password', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _proxySlotIdMeta =
      const VerificationMeta('proxySlotId');
  @override
  late final GeneratedColumn<int> proxySlotId = GeneratedColumn<int>(
      'proxy_slot_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES proxy_slots_table (id)'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        accountName,
        birthday,
        email,
        password,
        proxySlotId,
        createdAt,
        lastUpdated
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts_table';
  @override
  VerificationContext validateIntegrity(Insertable<AccountsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_name')) {
      context.handle(
          _accountNameMeta,
          accountName.isAcceptableOrUnknown(
              data['account_name']!, _accountNameMeta));
    } else if (isInserting) {
      context.missing(_accountNameMeta);
    }
    if (data.containsKey('birthday')) {
      context.handle(_birthdayMeta,
          birthday.isAcceptableOrUnknown(data['birthday']!, _birthdayMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('password')) {
      context.handle(_passwordMeta,
          password.isAcceptableOrUnknown(data['password']!, _passwordMeta));
    } else if (isInserting) {
      context.missing(_passwordMeta);
    }
    if (data.containsKey('proxy_slot_id')) {
      context.handle(
          _proxySlotIdMeta,
          proxySlotId.isAcceptableOrUnknown(
              data['proxy_slot_id']!, _proxySlotIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      accountName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_name'])!,
      birthday: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}birthday'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      password: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}password'])!,
      proxySlotId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}proxy_slot_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $AccountsTableTable createAlias(String alias) {
    return $AccountsTableTable(attachedDatabase, alias);
  }
}

class AccountsTableData extends DataClass
    implements Insertable<AccountsTableData> {
  /// Auto-increment primary key
  final int id;

  /// Account name/label
  final String accountName;

  /// Birthday (stored as string, e.g., '01-01-2000')
  final String birthday;

  /// Account email (unique)
  final String email;

  /// Account password
  final String password;

  /// Reference to the proxy slot this account uses (nullable)
  final int? proxySlotId;

  /// When this account was created
  final DateTime createdAt;

  /// When this account was last updated
  final DateTime lastUpdated;
  const AccountsTableData(
      {required this.id,
      required this.accountName,
      required this.birthday,
      required this.email,
      required this.password,
      this.proxySlotId,
      required this.createdAt,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_name'] = Variable<String>(accountName);
    map['birthday'] = Variable<String>(birthday);
    map['email'] = Variable<String>(email);
    map['password'] = Variable<String>(password);
    if (!nullToAbsent || proxySlotId != null) {
      map['proxy_slot_id'] = Variable<int>(proxySlotId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  AccountsTableCompanion toCompanion(bool nullToAbsent) {
    return AccountsTableCompanion(
      id: Value(id),
      accountName: Value(accountName),
      birthday: Value(birthday),
      email: Value(email),
      password: Value(password),
      proxySlotId: proxySlotId == null && nullToAbsent
          ? const Value.absent()
          : Value(proxySlotId),
      createdAt: Value(createdAt),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory AccountsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountsTableData(
      id: serializer.fromJson<int>(json['id']),
      accountName: serializer.fromJson<String>(json['accountName']),
      birthday: serializer.fromJson<String>(json['birthday']),
      email: serializer.fromJson<String>(json['email']),
      password: serializer.fromJson<String>(json['password']),
      proxySlotId: serializer.fromJson<int?>(json['proxySlotId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountName': serializer.toJson<String>(accountName),
      'birthday': serializer.toJson<String>(birthday),
      'email': serializer.toJson<String>(email),
      'password': serializer.toJson<String>(password),
      'proxySlotId': serializer.toJson<int?>(proxySlotId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  AccountsTableData copyWith(
          {int? id,
          String? accountName,
          String? birthday,
          String? email,
          String? password,
          Value<int?> proxySlotId = const Value.absent(),
          DateTime? createdAt,
          DateTime? lastUpdated}) =>
      AccountsTableData(
        id: id ?? this.id,
        accountName: accountName ?? this.accountName,
        birthday: birthday ?? this.birthday,
        email: email ?? this.email,
        password: password ?? this.password,
        proxySlotId: proxySlotId.present ? proxySlotId.value : this.proxySlotId,
        createdAt: createdAt ?? this.createdAt,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  AccountsTableData copyWithCompanion(AccountsTableCompanion data) {
    return AccountsTableData(
      id: data.id.present ? data.id.value : this.id,
      accountName:
          data.accountName.present ? data.accountName.value : this.accountName,
      birthday: data.birthday.present ? data.birthday.value : this.birthday,
      email: data.email.present ? data.email.value : this.email,
      password: data.password.present ? data.password.value : this.password,
      proxySlotId:
          data.proxySlotId.present ? data.proxySlotId.value : this.proxySlotId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountsTableData(')
          ..write('id: $id, ')
          ..write('accountName: $accountName, ')
          ..write('birthday: $birthday, ')
          ..write('email: $email, ')
          ..write('password: $password, ')
          ..write('proxySlotId: $proxySlotId, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountName, birthday, email, password,
      proxySlotId, createdAt, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountsTableData &&
          other.id == this.id &&
          other.accountName == this.accountName &&
          other.birthday == this.birthday &&
          other.email == this.email &&
          other.password == this.password &&
          other.proxySlotId == this.proxySlotId &&
          other.createdAt == this.createdAt &&
          other.lastUpdated == this.lastUpdated);
}

class AccountsTableCompanion extends UpdateCompanion<AccountsTableData> {
  final Value<int> id;
  final Value<String> accountName;
  final Value<String> birthday;
  final Value<String> email;
  final Value<String> password;
  final Value<int?> proxySlotId;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUpdated;
  const AccountsTableCompanion({
    this.id = const Value.absent(),
    this.accountName = const Value.absent(),
    this.birthday = const Value.absent(),
    this.email = const Value.absent(),
    this.password = const Value.absent(),
    this.proxySlotId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  AccountsTableCompanion.insert({
    this.id = const Value.absent(),
    required String accountName,
    this.birthday = const Value.absent(),
    required String email,
    required String password,
    this.proxySlotId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  })  : accountName = Value(accountName),
        email = Value(email),
        password = Value(password);
  static Insertable<AccountsTableData> custom({
    Expression<int>? id,
    Expression<String>? accountName,
    Expression<String>? birthday,
    Expression<String>? email,
    Expression<String>? password,
    Expression<int>? proxySlotId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountName != null) 'account_name': accountName,
      if (birthday != null) 'birthday': birthday,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
      if (proxySlotId != null) 'proxy_slot_id': proxySlotId,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  AccountsTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? accountName,
      Value<String>? birthday,
      Value<String>? email,
      Value<String>? password,
      Value<int?>? proxySlotId,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastUpdated}) {
    return AccountsTableCompanion(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      birthday: birthday ?? this.birthday,
      email: email ?? this.email,
      password: password ?? this.password,
      proxySlotId: proxySlotId ?? this.proxySlotId,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountName.present) {
      map['account_name'] = Variable<String>(accountName.value);
    }
    if (birthday.present) {
      map['birthday'] = Variable<String>(birthday.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (password.present) {
      map['password'] = Variable<String>(password.value);
    }
    if (proxySlotId.present) {
      map['proxy_slot_id'] = Variable<int>(proxySlotId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsTableCompanion(')
          ..write('id: $id, ')
          ..write('accountName: $accountName, ')
          ..write('birthday: $birthday, ')
          ..write('email: $email, ')
          ..write('password: $password, ')
          ..write('proxySlotId: $proxySlotId, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $CharactersTableTable extends CharactersTable
    with TableInfo<$CharactersTableTable, CharactersTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES accounts_table (id)'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bannedMeta = const VerificationMeta('banned');
  @override
  late final GeneratedColumn<bool> banned = GeneratedColumn<bool>(
      'banned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("banned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _actualSkillsJsonMeta =
      const VerificationMeta('actualSkillsJson');
  @override
  late final GeneratedColumn<String> actualSkillsJson = GeneratedColumn<String>(
      'actual_skills_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _targetSkillsJsonMeta =
      const VerificationMeta('targetSkillsJson');
  @override
  late final GeneratedColumn<String> targetSkillsJson = GeneratedColumn<String>(
      'target_skills_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastUpdatedMeta =
      const VerificationMeta('lastUpdated');
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
      'last_updated', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        accountId,
        name,
        banned,
        actualSkillsJson,
        targetSkillsJson,
        createdAt,
        lastUpdated
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<CharactersTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('banned')) {
      context.handle(_bannedMeta,
          banned.isAcceptableOrUnknown(data['banned']!, _bannedMeta));
    }
    if (data.containsKey('actual_skills_json')) {
      context.handle(
          _actualSkillsJsonMeta,
          actualSkillsJson.isAcceptableOrUnknown(
              data['actual_skills_json']!, _actualSkillsJsonMeta));
    }
    if (data.containsKey('target_skills_json')) {
      context.handle(
          _targetSkillsJsonMeta,
          targetSkillsJson.isAcceptableOrUnknown(
              data['target_skills_json']!, _targetSkillsJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_updated')) {
      context.handle(
          _lastUpdatedMeta,
          lastUpdated.isAcceptableOrUnknown(
              data['last_updated']!, _lastUpdatedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CharactersTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CharactersTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      banned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}banned'])!,
      actualSkillsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}actual_skills_json'])!,
      targetSkillsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}target_skills_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUpdated: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_updated'])!,
    );
  }

  @override
  $CharactersTableTable createAlias(String alias) {
    return $CharactersTableTable(attachedDatabase, alias);
  }
}

class CharactersTableData extends DataClass
    implements Insertable<CharactersTableData> {
  /// Auto-increment primary key
  final int id;

  /// Reference to the account this character belongs to
  final int accountId;

  /// Character name
  final String name;

  /// Whether this character is banned
  final bool banned;

  /// Actual skills stored as JSON string
  final String actualSkillsJson;

  /// Target skills stored as JSON string
  final String targetSkillsJson;

  /// When this character was created
  final DateTime createdAt;

  /// When this character was last updated
  final DateTime lastUpdated;
  const CharactersTableData(
      {required this.id,
      required this.accountId,
      required this.name,
      required this.banned,
      required this.actualSkillsJson,
      required this.targetSkillsJson,
      required this.createdAt,
      required this.lastUpdated});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['name'] = Variable<String>(name);
    map['banned'] = Variable<bool>(banned);
    map['actual_skills_json'] = Variable<String>(actualSkillsJson);
    map['target_skills_json'] = Variable<String>(targetSkillsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  CharactersTableCompanion toCompanion(bool nullToAbsent) {
    return CharactersTableCompanion(
      id: Value(id),
      accountId: Value(accountId),
      name: Value(name),
      banned: Value(banned),
      actualSkillsJson: Value(actualSkillsJson),
      targetSkillsJson: Value(targetSkillsJson),
      createdAt: Value(createdAt),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory CharactersTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CharactersTableData(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      name: serializer.fromJson<String>(json['name']),
      banned: serializer.fromJson<bool>(json['banned']),
      actualSkillsJson: serializer.fromJson<String>(json['actualSkillsJson']),
      targetSkillsJson: serializer.fromJson<String>(json['targetSkillsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'name': serializer.toJson<String>(name),
      'banned': serializer.toJson<bool>(banned),
      'actualSkillsJson': serializer.toJson<String>(actualSkillsJson),
      'targetSkillsJson': serializer.toJson<String>(targetSkillsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  CharactersTableData copyWith(
          {int? id,
          int? accountId,
          String? name,
          bool? banned,
          String? actualSkillsJson,
          String? targetSkillsJson,
          DateTime? createdAt,
          DateTime? lastUpdated}) =>
      CharactersTableData(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        name: name ?? this.name,
        banned: banned ?? this.banned,
        actualSkillsJson: actualSkillsJson ?? this.actualSkillsJson,
        targetSkillsJson: targetSkillsJson ?? this.targetSkillsJson,
        createdAt: createdAt ?? this.createdAt,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
  CharactersTableData copyWithCompanion(CharactersTableCompanion data) {
    return CharactersTableData(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      name: data.name.present ? data.name.value : this.name,
      banned: data.banned.present ? data.banned.value : this.banned,
      actualSkillsJson: data.actualSkillsJson.present
          ? data.actualSkillsJson.value
          : this.actualSkillsJson,
      targetSkillsJson: data.targetSkillsJson.present
          ? data.targetSkillsJson.value
          : this.targetSkillsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUpdated:
          data.lastUpdated.present ? data.lastUpdated.value : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CharactersTableData(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('name: $name, ')
          ..write('banned: $banned, ')
          ..write('actualSkillsJson: $actualSkillsJson, ')
          ..write('targetSkillsJson: $targetSkillsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, name, banned, actualSkillsJson,
      targetSkillsJson, createdAt, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CharactersTableData &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.name == this.name &&
          other.banned == this.banned &&
          other.actualSkillsJson == this.actualSkillsJson &&
          other.targetSkillsJson == this.targetSkillsJson &&
          other.createdAt == this.createdAt &&
          other.lastUpdated == this.lastUpdated);
}

class CharactersTableCompanion extends UpdateCompanion<CharactersTableData> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> name;
  final Value<bool> banned;
  final Value<String> actualSkillsJson;
  final Value<String> targetSkillsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> lastUpdated;
  const CharactersTableCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.name = const Value.absent(),
    this.banned = const Value.absent(),
    this.actualSkillsJson = const Value.absent(),
    this.targetSkillsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  CharactersTableCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String name,
    this.banned = const Value.absent(),
    this.actualSkillsJson = const Value.absent(),
    this.targetSkillsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  })  : accountId = Value(accountId),
        name = Value(name);
  static Insertable<CharactersTableData> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? name,
    Expression<bool>? banned,
    Expression<String>? actualSkillsJson,
    Expression<String>? targetSkillsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (name != null) 'name': name,
      if (banned != null) 'banned': banned,
      if (actualSkillsJson != null) 'actual_skills_json': actualSkillsJson,
      if (targetSkillsJson != null) 'target_skills_json': targetSkillsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  CharactersTableCompanion copyWith(
      {Value<int>? id,
      Value<int>? accountId,
      Value<String>? name,
      Value<bool>? banned,
      Value<String>? actualSkillsJson,
      Value<String>? targetSkillsJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? lastUpdated}) {
    return CharactersTableCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      banned: banned ?? this.banned,
      actualSkillsJson: actualSkillsJson ?? this.actualSkillsJson,
      targetSkillsJson: targetSkillsJson ?? this.targetSkillsJson,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (banned.present) {
      map['banned'] = Variable<bool>(banned.value);
    }
    if (actualSkillsJson.present) {
      map['actual_skills_json'] = Variable<String>(actualSkillsJson.value);
    }
    if (targetSkillsJson.present) {
      map['target_skills_json'] = Variable<String>(targetSkillsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharactersTableCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('name: $name, ')
          ..write('banned: $banned, ')
          ..write('actualSkillsJson: $actualSkillsJson, ')
          ..write('targetSkillsJson: $targetSkillsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppConfigTableTable appConfigTable = $AppConfigTableTable(this);
  late final $ProxySlotsTableTable proxySlotsTable =
      $ProxySlotsTableTable(this);
  late final $ProxyIpAddressesTableTable proxyIpAddressesTable =
      $ProxyIpAddressesTableTable(this);
  late final $AccountsTableTable accountsTable = $AccountsTableTable(this);
  late final $CharactersTableTable charactersTable =
      $CharactersTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appConfigTable,
        proxySlotsTable,
        proxyIpAddressesTable,
        accountsTable,
        charactersTable
      ];
}

typedef $$AppConfigTableTableCreateCompanionBuilder = AppConfigTableCompanion
    Function({
  required String key,
  required String value,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
  Value<int> rowid,
});
typedef $$AppConfigTableTableUpdateCompanionBuilder = AppConfigTableCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
  Value<int> rowid,
});

class $$AppConfigTableTableFilterComposer
    extends Composer<_$AppDatabase, $AppConfigTableTable> {
  $$AppConfigTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));
}

class $$AppConfigTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AppConfigTableTable> {
  $$AppConfigTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));
}

class $$AppConfigTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppConfigTableTable> {
  $$AppConfigTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);
}

class $$AppConfigTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppConfigTableTable,
    AppConfigTableData,
    $$AppConfigTableTableFilterComposer,
    $$AppConfigTableTableOrderingComposer,
    $$AppConfigTableTableAnnotationComposer,
    $$AppConfigTableTableCreateCompanionBuilder,
    $$AppConfigTableTableUpdateCompanionBuilder,
    (
      AppConfigTableData,
      BaseReferences<_$AppDatabase, $AppConfigTableTable, AppConfigTableData>
    ),
    AppConfigTableData,
    PrefetchHooks Function()> {
  $$AppConfigTableTableTableManager(
      _$AppDatabase db, $AppConfigTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppConfigTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppConfigTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppConfigTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppConfigTableCompanion(
            key: key,
            value: value,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppConfigTableCompanion.insert(
            key: key,
            value: value,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppConfigTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppConfigTableTable,
    AppConfigTableData,
    $$AppConfigTableTableFilterComposer,
    $$AppConfigTableTableOrderingComposer,
    $$AppConfigTableTableAnnotationComposer,
    $$AppConfigTableTableCreateCompanionBuilder,
    $$AppConfigTableTableUpdateCompanionBuilder,
    (
      AppConfigTableData,
      BaseReferences<_$AppDatabase, $AppConfigTableTable, AppConfigTableData>
    ),
    AppConfigTableData,
    PrefetchHooks Function()>;
typedef $$ProxySlotsTableTableCreateCompanionBuilder = ProxySlotsTableCompanion
    Function({
  Value<int> id,
  required String webshareId,
  Value<String> slotName,
  required int slotNumber,
  Value<int?> currentIpAddressId,
  required String username,
  required String password,
  Value<int> port,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
  Value<int> totalIpChanges,
  Value<bool> isActive,
});
typedef $$ProxySlotsTableTableUpdateCompanionBuilder = ProxySlotsTableCompanion
    Function({
  Value<int> id,
  Value<String> webshareId,
  Value<String> slotName,
  Value<int> slotNumber,
  Value<int?> currentIpAddressId,
  Value<String> username,
  Value<String> password,
  Value<int> port,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
  Value<int> totalIpChanges,
  Value<bool> isActive,
});

final class $$ProxySlotsTableTableReferences extends BaseReferences<
    _$AppDatabase, $ProxySlotsTableTable, ProxySlotsTableData> {
  $$ProxySlotsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProxyIpAddressesTableTable,
      List<ProxyIpAddressesTableData>> _proxyIpAddressesTableRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.proxyIpAddressesTable,
          aliasName: $_aliasNameGenerator(
              db.proxySlotsTable.id, db.proxyIpAddressesTable.slotId));

  $$ProxyIpAddressesTableTableProcessedTableManager
      get proxyIpAddressesTableRefs {
    final manager = $$ProxyIpAddressesTableTableTableManager(
            $_db, $_db.proxyIpAddressesTable)
        .filter((f) => f.slotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_proxyIpAddressesTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AccountsTableTable, List<AccountsTableData>>
      _accountsTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.accountsTable,
              aliasName: $_aliasNameGenerator(
                  db.proxySlotsTable.id, db.accountsTable.proxySlotId));

  $$AccountsTableTableProcessedTableManager get accountsTableRefs {
    final manager = $$AccountsTableTableTableManager($_db, $_db.accountsTable)
        .filter((f) => f.proxySlotId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_accountsTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProxySlotsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ProxySlotsTableTable> {
  $$ProxySlotsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get webshareId => $composableBuilder(
      column: $table.webshareId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get slotName => $composableBuilder(
      column: $table.slotName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get slotNumber => $composableBuilder(
      column: $table.slotNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentIpAddressId => $composableBuilder(
      column: $table.currentIpAddressId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get port => $composableBuilder(
      column: $table.port, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalIpChanges => $composableBuilder(
      column: $table.totalIpChanges,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  Expression<bool> proxyIpAddressesTableRefs(
      Expression<bool> Function($$ProxyIpAddressesTableTableFilterComposer f)
          f) {
    final $$ProxyIpAddressesTableTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.proxyIpAddressesTable,
            getReferencedColumn: (t) => t.slotId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ProxyIpAddressesTableTableFilterComposer(
                  $db: $db,
                  $table: $db.proxyIpAddressesTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<bool> accountsTableRefs(
      Expression<bool> Function($$AccountsTableTableFilterComposer f) f) {
    final $$AccountsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.accountsTable,
        getReferencedColumn: (t) => t.proxySlotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableTableFilterComposer(
              $db: $db,
              $table: $db.accountsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProxySlotsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ProxySlotsTableTable> {
  $$ProxySlotsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get webshareId => $composableBuilder(
      column: $table.webshareId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get slotName => $composableBuilder(
      column: $table.slotName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get slotNumber => $composableBuilder(
      column: $table.slotNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentIpAddressId => $composableBuilder(
      column: $table.currentIpAddressId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get port => $composableBuilder(
      column: $table.port, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalIpChanges => $composableBuilder(
      column: $table.totalIpChanges,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
}

class $$ProxySlotsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProxySlotsTableTable> {
  $$ProxySlotsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get webshareId => $composableBuilder(
      column: $table.webshareId, builder: (column) => column);

  GeneratedColumn<String> get slotName =>
      $composableBuilder(column: $table.slotName, builder: (column) => column);

  GeneratedColumn<int> get slotNumber => $composableBuilder(
      column: $table.slotNumber, builder: (column) => column);

  GeneratedColumn<int> get currentIpAddressId => $composableBuilder(
      column: $table.currentIpAddressId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  GeneratedColumn<int> get totalIpChanges => $composableBuilder(
      column: $table.totalIpChanges, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  Expression<T> proxyIpAddressesTableRefs<T extends Object>(
      Expression<T> Function($$ProxyIpAddressesTableTableAnnotationComposer a)
          f) {
    final $$ProxyIpAddressesTableTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.proxyIpAddressesTable,
            getReferencedColumn: (t) => t.slotId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ProxyIpAddressesTableTableAnnotationComposer(
                  $db: $db,
                  $table: $db.proxyIpAddressesTable,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> accountsTableRefs<T extends Object>(
      Expression<T> Function($$AccountsTableTableAnnotationComposer a) f) {
    final $$AccountsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.accountsTable,
        getReferencedColumn: (t) => t.proxySlotId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.accountsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProxySlotsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProxySlotsTableTable,
    ProxySlotsTableData,
    $$ProxySlotsTableTableFilterComposer,
    $$ProxySlotsTableTableOrderingComposer,
    $$ProxySlotsTableTableAnnotationComposer,
    $$ProxySlotsTableTableCreateCompanionBuilder,
    $$ProxySlotsTableTableUpdateCompanionBuilder,
    (ProxySlotsTableData, $$ProxySlotsTableTableReferences),
    ProxySlotsTableData,
    PrefetchHooks Function(
        {bool proxyIpAddressesTableRefs, bool accountsTableRefs})> {
  $$ProxySlotsTableTableTableManager(
      _$AppDatabase db, $ProxySlotsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProxySlotsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProxySlotsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProxySlotsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> webshareId = const Value.absent(),
            Value<String> slotName = const Value.absent(),
            Value<int> slotNumber = const Value.absent(),
            Value<int?> currentIpAddressId = const Value.absent(),
            Value<String> username = const Value.absent(),
            Value<String> password = const Value.absent(),
            Value<int> port = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
            Value<int> totalIpChanges = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              ProxySlotsTableCompanion(
            id: id,
            webshareId: webshareId,
            slotName: slotName,
            slotNumber: slotNumber,
            currentIpAddressId: currentIpAddressId,
            username: username,
            password: password,
            port: port,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            totalIpChanges: totalIpChanges,
            isActive: isActive,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String webshareId,
            Value<String> slotName = const Value.absent(),
            required int slotNumber,
            Value<int?> currentIpAddressId = const Value.absent(),
            required String username,
            required String password,
            Value<int> port = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
            Value<int> totalIpChanges = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
          }) =>
              ProxySlotsTableCompanion.insert(
            id: id,
            webshareId: webshareId,
            slotName: slotName,
            slotNumber: slotNumber,
            currentIpAddressId: currentIpAddressId,
            username: username,
            password: password,
            port: port,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
            totalIpChanges: totalIpChanges,
            isActive: isActive,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ProxySlotsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {proxyIpAddressesTableRefs = false, accountsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (proxyIpAddressesTableRefs) db.proxyIpAddressesTable,
                if (accountsTableRefs) db.accountsTable
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (proxyIpAddressesTableRefs)
                    await $_getPrefetchedData<ProxySlotsTableData,
                            $ProxySlotsTableTable, ProxyIpAddressesTableData>(
                        currentTable: table,
                        referencedTable: $$ProxySlotsTableTableReferences
                            ._proxyIpAddressesTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProxySlotsTableTableReferences(db, table, p0)
                                .proxyIpAddressesTableRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.slotId == item.id),
                        typedResults: items),
                  if (accountsTableRefs)
                    await $_getPrefetchedData<ProxySlotsTableData,
                            $ProxySlotsTableTable, AccountsTableData>(
                        currentTable: table,
                        referencedTable: $$ProxySlotsTableTableReferences
                            ._accountsTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProxySlotsTableTableReferences(db, table, p0)
                                .accountsTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.proxySlotId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProxySlotsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProxySlotsTableTable,
    ProxySlotsTableData,
    $$ProxySlotsTableTableFilterComposer,
    $$ProxySlotsTableTableOrderingComposer,
    $$ProxySlotsTableTableAnnotationComposer,
    $$ProxySlotsTableTableCreateCompanionBuilder,
    $$ProxySlotsTableTableUpdateCompanionBuilder,
    (ProxySlotsTableData, $$ProxySlotsTableTableReferences),
    ProxySlotsTableData,
    PrefetchHooks Function(
        {bool proxyIpAddressesTableRefs, bool accountsTableRefs})>;
typedef $$ProxyIpAddressesTableTableCreateCompanionBuilder
    = ProxyIpAddressesTableCompanion Function({
  Value<int> id,
  required String ipAddress,
  Value<String> hostname,
  required int slotId,
  Value<bool> isActive,
  Value<String> countryCode,
  Value<String> cityName,
  Value<String> ipTimezone,
  Value<bool> highCountryConfidence,
  Value<String> asnName,
  Value<int> asnNumber,
  Value<double> ipScore,
  Value<String> scoreLevel,
  Value<bool> isVpn,
  Value<bool> isProxy,
  Value<bool> isDatacenter,
  Value<bool> isTor,
  Value<double> fraudScore,
  Value<int> abuseConfidence,
  Value<DateTime> assignedAt,
  Value<DateTime?> removedAt,
  Value<DateTime> lastVerification,
  Value<DateTime?> lastScoreCheck,
  Value<int> totalDaysUsed,
  Value<int> timesAssigned,
});
typedef $$ProxyIpAddressesTableTableUpdateCompanionBuilder
    = ProxyIpAddressesTableCompanion Function({
  Value<int> id,
  Value<String> ipAddress,
  Value<String> hostname,
  Value<int> slotId,
  Value<bool> isActive,
  Value<String> countryCode,
  Value<String> cityName,
  Value<String> ipTimezone,
  Value<bool> highCountryConfidence,
  Value<String> asnName,
  Value<int> asnNumber,
  Value<double> ipScore,
  Value<String> scoreLevel,
  Value<bool> isVpn,
  Value<bool> isProxy,
  Value<bool> isDatacenter,
  Value<bool> isTor,
  Value<double> fraudScore,
  Value<int> abuseConfidence,
  Value<DateTime> assignedAt,
  Value<DateTime?> removedAt,
  Value<DateTime> lastVerification,
  Value<DateTime?> lastScoreCheck,
  Value<int> totalDaysUsed,
  Value<int> timesAssigned,
});

final class $$ProxyIpAddressesTableTableReferences extends BaseReferences<
    _$AppDatabase, $ProxyIpAddressesTableTable, ProxyIpAddressesTableData> {
  $$ProxyIpAddressesTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProxySlotsTableTable _slotIdTable(_$AppDatabase db) =>
      db.proxySlotsTable.createAlias($_aliasNameGenerator(
          db.proxyIpAddressesTable.slotId, db.proxySlotsTable.id));

  $$ProxySlotsTableTableProcessedTableManager get slotId {
    final $_column = $_itemColumn<int>('slot_id')!;

    final manager =
        $$ProxySlotsTableTableTableManager($_db, $_db.proxySlotsTable)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_slotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ProxyIpAddressesTableTableFilterComposer
    extends Composer<_$AppDatabase, $ProxyIpAddressesTableTable> {
  $$ProxyIpAddressesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ipAddress => $composableBuilder(
      column: $table.ipAddress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hostname => $composableBuilder(
      column: $table.hostname, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get countryCode => $composableBuilder(
      column: $table.countryCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cityName => $composableBuilder(
      column: $table.cityName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ipTimezone => $composableBuilder(
      column: $table.ipTimezone, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get highCountryConfidence => $composableBuilder(
      column: $table.highCountryConfidence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get asnName => $composableBuilder(
      column: $table.asnName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get asnNumber => $composableBuilder(
      column: $table.asnNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ipScore => $composableBuilder(
      column: $table.ipScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scoreLevel => $composableBuilder(
      column: $table.scoreLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVpn => $composableBuilder(
      column: $table.isVpn, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isProxy => $composableBuilder(
      column: $table.isProxy, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDatacenter => $composableBuilder(
      column: $table.isDatacenter, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isTor => $composableBuilder(
      column: $table.isTor, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get fraudScore => $composableBuilder(
      column: $table.fraudScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get abuseConfidence => $composableBuilder(
      column: $table.abuseConfidence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get assignedAt => $composableBuilder(
      column: $table.assignedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get removedAt => $composableBuilder(
      column: $table.removedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastVerification => $composableBuilder(
      column: $table.lastVerification,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastScoreCheck => $composableBuilder(
      column: $table.lastScoreCheck,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalDaysUsed => $composableBuilder(
      column: $table.totalDaysUsed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timesAssigned => $composableBuilder(
      column: $table.timesAssigned, builder: (column) => ColumnFilters(column));

  $$ProxySlotsTableTableFilterComposer get slotId {
    final $$ProxySlotsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.proxySlotsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProxySlotsTableTableFilterComposer(
              $db: $db,
              $table: $db.proxySlotsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProxyIpAddressesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ProxyIpAddressesTableTable> {
  $$ProxyIpAddressesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ipAddress => $composableBuilder(
      column: $table.ipAddress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hostname => $composableBuilder(
      column: $table.hostname, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get countryCode => $composableBuilder(
      column: $table.countryCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cityName => $composableBuilder(
      column: $table.cityName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ipTimezone => $composableBuilder(
      column: $table.ipTimezone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get highCountryConfidence => $composableBuilder(
      column: $table.highCountryConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get asnName => $composableBuilder(
      column: $table.asnName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get asnNumber => $composableBuilder(
      column: $table.asnNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ipScore => $composableBuilder(
      column: $table.ipScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scoreLevel => $composableBuilder(
      column: $table.scoreLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVpn => $composableBuilder(
      column: $table.isVpn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isProxy => $composableBuilder(
      column: $table.isProxy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDatacenter => $composableBuilder(
      column: $table.isDatacenter,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isTor => $composableBuilder(
      column: $table.isTor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get fraudScore => $composableBuilder(
      column: $table.fraudScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get abuseConfidence => $composableBuilder(
      column: $table.abuseConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get assignedAt => $composableBuilder(
      column: $table.assignedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get removedAt => $composableBuilder(
      column: $table.removedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastVerification => $composableBuilder(
      column: $table.lastVerification,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastScoreCheck => $composableBuilder(
      column: $table.lastScoreCheck,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalDaysUsed => $composableBuilder(
      column: $table.totalDaysUsed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timesAssigned => $composableBuilder(
      column: $table.timesAssigned,
      builder: (column) => ColumnOrderings(column));

  $$ProxySlotsTableTableOrderingComposer get slotId {
    final $$ProxySlotsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.proxySlotsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProxySlotsTableTableOrderingComposer(
              $db: $db,
              $table: $db.proxySlotsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProxyIpAddressesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProxyIpAddressesTableTable> {
  $$ProxyIpAddressesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ipAddress =>
      $composableBuilder(column: $table.ipAddress, builder: (column) => column);

  GeneratedColumn<String> get hostname =>
      $composableBuilder(column: $table.hostname, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get countryCode => $composableBuilder(
      column: $table.countryCode, builder: (column) => column);

  GeneratedColumn<String> get cityName =>
      $composableBuilder(column: $table.cityName, builder: (column) => column);

  GeneratedColumn<String> get ipTimezone => $composableBuilder(
      column: $table.ipTimezone, builder: (column) => column);

  GeneratedColumn<bool> get highCountryConfidence => $composableBuilder(
      column: $table.highCountryConfidence, builder: (column) => column);

  GeneratedColumn<String> get asnName =>
      $composableBuilder(column: $table.asnName, builder: (column) => column);

  GeneratedColumn<int> get asnNumber =>
      $composableBuilder(column: $table.asnNumber, builder: (column) => column);

  GeneratedColumn<double> get ipScore =>
      $composableBuilder(column: $table.ipScore, builder: (column) => column);

  GeneratedColumn<String> get scoreLevel => $composableBuilder(
      column: $table.scoreLevel, builder: (column) => column);

  GeneratedColumn<bool> get isVpn =>
      $composableBuilder(column: $table.isVpn, builder: (column) => column);

  GeneratedColumn<bool> get isProxy =>
      $composableBuilder(column: $table.isProxy, builder: (column) => column);

  GeneratedColumn<bool> get isDatacenter => $composableBuilder(
      column: $table.isDatacenter, builder: (column) => column);

  GeneratedColumn<bool> get isTor =>
      $composableBuilder(column: $table.isTor, builder: (column) => column);

  GeneratedColumn<double> get fraudScore => $composableBuilder(
      column: $table.fraudScore, builder: (column) => column);

  GeneratedColumn<int> get abuseConfidence => $composableBuilder(
      column: $table.abuseConfidence, builder: (column) => column);

  GeneratedColumn<DateTime> get assignedAt => $composableBuilder(
      column: $table.assignedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get removedAt =>
      $composableBuilder(column: $table.removedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastVerification => $composableBuilder(
      column: $table.lastVerification, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScoreCheck => $composableBuilder(
      column: $table.lastScoreCheck, builder: (column) => column);

  GeneratedColumn<int> get totalDaysUsed => $composableBuilder(
      column: $table.totalDaysUsed, builder: (column) => column);

  GeneratedColumn<int> get timesAssigned => $composableBuilder(
      column: $table.timesAssigned, builder: (column) => column);

  $$ProxySlotsTableTableAnnotationComposer get slotId {
    final $$ProxySlotsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.slotId,
        referencedTable: $db.proxySlotsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProxySlotsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.proxySlotsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProxyIpAddressesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProxyIpAddressesTableTable,
    ProxyIpAddressesTableData,
    $$ProxyIpAddressesTableTableFilterComposer,
    $$ProxyIpAddressesTableTableOrderingComposer,
    $$ProxyIpAddressesTableTableAnnotationComposer,
    $$ProxyIpAddressesTableTableCreateCompanionBuilder,
    $$ProxyIpAddressesTableTableUpdateCompanionBuilder,
    (ProxyIpAddressesTableData, $$ProxyIpAddressesTableTableReferences),
    ProxyIpAddressesTableData,
    PrefetchHooks Function({bool slotId})> {
  $$ProxyIpAddressesTableTableTableManager(
      _$AppDatabase db, $ProxyIpAddressesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProxyIpAddressesTableTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ProxyIpAddressesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProxyIpAddressesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> ipAddress = const Value.absent(),
            Value<String> hostname = const Value.absent(),
            Value<int> slotId = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> countryCode = const Value.absent(),
            Value<String> cityName = const Value.absent(),
            Value<String> ipTimezone = const Value.absent(),
            Value<bool> highCountryConfidence = const Value.absent(),
            Value<String> asnName = const Value.absent(),
            Value<int> asnNumber = const Value.absent(),
            Value<double> ipScore = const Value.absent(),
            Value<String> scoreLevel = const Value.absent(),
            Value<bool> isVpn = const Value.absent(),
            Value<bool> isProxy = const Value.absent(),
            Value<bool> isDatacenter = const Value.absent(),
            Value<bool> isTor = const Value.absent(),
            Value<double> fraudScore = const Value.absent(),
            Value<int> abuseConfidence = const Value.absent(),
            Value<DateTime> assignedAt = const Value.absent(),
            Value<DateTime?> removedAt = const Value.absent(),
            Value<DateTime> lastVerification = const Value.absent(),
            Value<DateTime?> lastScoreCheck = const Value.absent(),
            Value<int> totalDaysUsed = const Value.absent(),
            Value<int> timesAssigned = const Value.absent(),
          }) =>
              ProxyIpAddressesTableCompanion(
            id: id,
            ipAddress: ipAddress,
            hostname: hostname,
            slotId: slotId,
            isActive: isActive,
            countryCode: countryCode,
            cityName: cityName,
            ipTimezone: ipTimezone,
            highCountryConfidence: highCountryConfidence,
            asnName: asnName,
            asnNumber: asnNumber,
            ipScore: ipScore,
            scoreLevel: scoreLevel,
            isVpn: isVpn,
            isProxy: isProxy,
            isDatacenter: isDatacenter,
            isTor: isTor,
            fraudScore: fraudScore,
            abuseConfidence: abuseConfidence,
            assignedAt: assignedAt,
            removedAt: removedAt,
            lastVerification: lastVerification,
            lastScoreCheck: lastScoreCheck,
            totalDaysUsed: totalDaysUsed,
            timesAssigned: timesAssigned,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String ipAddress,
            Value<String> hostname = const Value.absent(),
            required int slotId,
            Value<bool> isActive = const Value.absent(),
            Value<String> countryCode = const Value.absent(),
            Value<String> cityName = const Value.absent(),
            Value<String> ipTimezone = const Value.absent(),
            Value<bool> highCountryConfidence = const Value.absent(),
            Value<String> asnName = const Value.absent(),
            Value<int> asnNumber = const Value.absent(),
            Value<double> ipScore = const Value.absent(),
            Value<String> scoreLevel = const Value.absent(),
            Value<bool> isVpn = const Value.absent(),
            Value<bool> isProxy = const Value.absent(),
            Value<bool> isDatacenter = const Value.absent(),
            Value<bool> isTor = const Value.absent(),
            Value<double> fraudScore = const Value.absent(),
            Value<int> abuseConfidence = const Value.absent(),
            Value<DateTime> assignedAt = const Value.absent(),
            Value<DateTime?> removedAt = const Value.absent(),
            Value<DateTime> lastVerification = const Value.absent(),
            Value<DateTime?> lastScoreCheck = const Value.absent(),
            Value<int> totalDaysUsed = const Value.absent(),
            Value<int> timesAssigned = const Value.absent(),
          }) =>
              ProxyIpAddressesTableCompanion.insert(
            id: id,
            ipAddress: ipAddress,
            hostname: hostname,
            slotId: slotId,
            isActive: isActive,
            countryCode: countryCode,
            cityName: cityName,
            ipTimezone: ipTimezone,
            highCountryConfidence: highCountryConfidence,
            asnName: asnName,
            asnNumber: asnNumber,
            ipScore: ipScore,
            scoreLevel: scoreLevel,
            isVpn: isVpn,
            isProxy: isProxy,
            isDatacenter: isDatacenter,
            isTor: isTor,
            fraudScore: fraudScore,
            abuseConfidence: abuseConfidence,
            assignedAt: assignedAt,
            removedAt: removedAt,
            lastVerification: lastVerification,
            lastScoreCheck: lastScoreCheck,
            totalDaysUsed: totalDaysUsed,
            timesAssigned: timesAssigned,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ProxyIpAddressesTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({slotId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (slotId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.slotId,
                    referencedTable:
                        $$ProxyIpAddressesTableTableReferences._slotIdTable(db),
                    referencedColumn: $$ProxyIpAddressesTableTableReferences
                        ._slotIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ProxyIpAddressesTableTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $ProxyIpAddressesTableTable,
        ProxyIpAddressesTableData,
        $$ProxyIpAddressesTableTableFilterComposer,
        $$ProxyIpAddressesTableTableOrderingComposer,
        $$ProxyIpAddressesTableTableAnnotationComposer,
        $$ProxyIpAddressesTableTableCreateCompanionBuilder,
        $$ProxyIpAddressesTableTableUpdateCompanionBuilder,
        (ProxyIpAddressesTableData, $$ProxyIpAddressesTableTableReferences),
        ProxyIpAddressesTableData,
        PrefetchHooks Function({bool slotId})>;
typedef $$AccountsTableTableCreateCompanionBuilder = AccountsTableCompanion
    Function({
  Value<int> id,
  required String accountName,
  Value<String> birthday,
  required String email,
  required String password,
  Value<int?> proxySlotId,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
});
typedef $$AccountsTableTableUpdateCompanionBuilder = AccountsTableCompanion
    Function({
  Value<int> id,
  Value<String> accountName,
  Value<String> birthday,
  Value<String> email,
  Value<String> password,
  Value<int?> proxySlotId,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
});

final class $$AccountsTableTableReferences extends BaseReferences<_$AppDatabase,
    $AccountsTableTable, AccountsTableData> {
  $$AccountsTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProxySlotsTableTable _proxySlotIdTable(_$AppDatabase db) =>
      db.proxySlotsTable.createAlias($_aliasNameGenerator(
          db.accountsTable.proxySlotId, db.proxySlotsTable.id));

  $$ProxySlotsTableTableProcessedTableManager? get proxySlotId {
    final $_column = $_itemColumn<int>('proxy_slot_id');
    if ($_column == null) return null;
    final manager =
        $$ProxySlotsTableTableTableManager($_db, $_db.proxySlotsTable)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_proxySlotIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$CharactersTableTable, List<CharactersTableData>>
      _charactersTableRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.charactersTable,
              aliasName: $_aliasNameGenerator(
                  db.accountsTable.id, db.charactersTable.accountId));

  $$CharactersTableTableProcessedTableManager get charactersTableRefs {
    final manager =
        $$CharactersTableTableTableManager($_db, $_db.charactersTable)
            .filter((f) => f.accountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_charactersTableRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$AccountsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountName => $composableBuilder(
      column: $table.accountName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get birthday => $composableBuilder(
      column: $table.birthday, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  $$ProxySlotsTableTableFilterComposer get proxySlotId {
    final $$ProxySlotsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.proxySlotId,
        referencedTable: $db.proxySlotsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProxySlotsTableTableFilterComposer(
              $db: $db,
              $table: $db.proxySlotsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> charactersTableRefs(
      Expression<bool> Function($$CharactersTableTableFilterComposer f) f) {
    final $$CharactersTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.charactersTable,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableTableFilterComposer(
              $db: $db,
              $table: $db.charactersTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AccountsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountName => $composableBuilder(
      column: $table.accountName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get birthday => $composableBuilder(
      column: $table.birthday, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get password => $composableBuilder(
      column: $table.password, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  $$ProxySlotsTableTableOrderingComposer get proxySlotId {
    final $$ProxySlotsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.proxySlotId,
        referencedTable: $db.proxySlotsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProxySlotsTableTableOrderingComposer(
              $db: $db,
              $table: $db.proxySlotsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AccountsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountName => $composableBuilder(
      column: $table.accountName, builder: (column) => column);

  GeneratedColumn<String> get birthday =>
      $composableBuilder(column: $table.birthday, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get password =>
      $composableBuilder(column: $table.password, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  $$ProxySlotsTableTableAnnotationComposer get proxySlotId {
    final $$ProxySlotsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.proxySlotId,
        referencedTable: $db.proxySlotsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProxySlotsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.proxySlotsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> charactersTableRefs<T extends Object>(
      Expression<T> Function($$CharactersTableTableAnnotationComposer a) f) {
    final $$CharactersTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.charactersTable,
        getReferencedColumn: (t) => t.accountId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CharactersTableTableAnnotationComposer(
              $db: $db,
              $table: $db.charactersTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$AccountsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTableTable,
    AccountsTableData,
    $$AccountsTableTableFilterComposer,
    $$AccountsTableTableOrderingComposer,
    $$AccountsTableTableAnnotationComposer,
    $$AccountsTableTableCreateCompanionBuilder,
    $$AccountsTableTableUpdateCompanionBuilder,
    (AccountsTableData, $$AccountsTableTableReferences),
    AccountsTableData,
    PrefetchHooks Function({bool proxySlotId, bool charactersTableRefs})> {
  $$AccountsTableTableTableManager(_$AppDatabase db, $AccountsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> accountName = const Value.absent(),
            Value<String> birthday = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> password = const Value.absent(),
            Value<int?> proxySlotId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              AccountsTableCompanion(
            id: id,
            accountName: accountName,
            birthday: birthday,
            email: email,
            password: password,
            proxySlotId: proxySlotId,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String accountName,
            Value<String> birthday = const Value.absent(),
            required String email,
            required String password,
            Value<int?> proxySlotId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              AccountsTableCompanion.insert(
            id: id,
            accountName: accountName,
            birthday: birthday,
            email: email,
            password: password,
            proxySlotId: proxySlotId,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AccountsTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {proxySlotId = false, charactersTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (charactersTableRefs) db.charactersTable
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (proxySlotId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.proxySlotId,
                    referencedTable:
                        $$AccountsTableTableReferences._proxySlotIdTable(db),
                    referencedColumn:
                        $$AccountsTableTableReferences._proxySlotIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (charactersTableRefs)
                    await $_getPrefetchedData<AccountsTableData,
                            $AccountsTableTable, CharactersTableData>(
                        currentTable: table,
                        referencedTable: $$AccountsTableTableReferences
                            ._charactersTableRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$AccountsTableTableReferences(db, table, p0)
                                .charactersTableRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.accountId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$AccountsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTableTable,
    AccountsTableData,
    $$AccountsTableTableFilterComposer,
    $$AccountsTableTableOrderingComposer,
    $$AccountsTableTableAnnotationComposer,
    $$AccountsTableTableCreateCompanionBuilder,
    $$AccountsTableTableUpdateCompanionBuilder,
    (AccountsTableData, $$AccountsTableTableReferences),
    AccountsTableData,
    PrefetchHooks Function({bool proxySlotId, bool charactersTableRefs})>;
typedef $$CharactersTableTableCreateCompanionBuilder = CharactersTableCompanion
    Function({
  Value<int> id,
  required int accountId,
  required String name,
  Value<bool> banned,
  Value<String> actualSkillsJson,
  Value<String> targetSkillsJson,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
});
typedef $$CharactersTableTableUpdateCompanionBuilder = CharactersTableCompanion
    Function({
  Value<int> id,
  Value<int> accountId,
  Value<String> name,
  Value<bool> banned,
  Value<String> actualSkillsJson,
  Value<String> targetSkillsJson,
  Value<DateTime> createdAt,
  Value<DateTime> lastUpdated,
});

final class $$CharactersTableTableReferences extends BaseReferences<
    _$AppDatabase, $CharactersTableTable, CharactersTableData> {
  $$CharactersTableTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTableTable _accountIdTable(_$AppDatabase db) =>
      db.accountsTable.createAlias($_aliasNameGenerator(
          db.charactersTable.accountId, db.accountsTable.id));

  $$AccountsTableTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<int>('account_id')!;

    final manager = $$AccountsTableTableTableManager($_db, $_db.accountsTable)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CharactersTableTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTableTable> {
  $$CharactersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get banned => $composableBuilder(
      column: $table.banned, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actualSkillsJson => $composableBuilder(
      column: $table.actualSkillsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetSkillsJson => $composableBuilder(
      column: $table.targetSkillsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnFilters(column));

  $$AccountsTableTableFilterComposer get accountId {
    final $$AccountsTableTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accountsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableTableFilterComposer(
              $db: $db,
              $table: $db.accountsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharactersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTableTable> {
  $$CharactersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get banned => $composableBuilder(
      column: $table.banned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actualSkillsJson => $composableBuilder(
      column: $table.actualSkillsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetSkillsJson => $composableBuilder(
      column: $table.targetSkillsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => ColumnOrderings(column));

  $$AccountsTableTableOrderingComposer get accountId {
    final $$AccountsTableTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accountsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableTableOrderingComposer(
              $db: $db,
              $table: $db.accountsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharactersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTableTable> {
  $$CharactersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get banned =>
      $composableBuilder(column: $table.banned, builder: (column) => column);

  GeneratedColumn<String> get actualSkillsJson => $composableBuilder(
      column: $table.actualSkillsJson, builder: (column) => column);

  GeneratedColumn<String> get targetSkillsJson => $composableBuilder(
      column: $table.targetSkillsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
      column: $table.lastUpdated, builder: (column) => column);

  $$AccountsTableTableAnnotationComposer get accountId {
    final $$AccountsTableTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.accountId,
        referencedTable: $db.accountsTable,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AccountsTableTableAnnotationComposer(
              $db: $db,
              $table: $db.accountsTable,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CharactersTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CharactersTableTable,
    CharactersTableData,
    $$CharactersTableTableFilterComposer,
    $$CharactersTableTableOrderingComposer,
    $$CharactersTableTableAnnotationComposer,
    $$CharactersTableTableCreateCompanionBuilder,
    $$CharactersTableTableUpdateCompanionBuilder,
    (CharactersTableData, $$CharactersTableTableReferences),
    CharactersTableData,
    PrefetchHooks Function({bool accountId})> {
  $$CharactersTableTableTableManager(
      _$AppDatabase db, $CharactersTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> accountId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<bool> banned = const Value.absent(),
            Value<String> actualSkillsJson = const Value.absent(),
            Value<String> targetSkillsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              CharactersTableCompanion(
            id: id,
            accountId: accountId,
            name: name,
            banned: banned,
            actualSkillsJson: actualSkillsJson,
            targetSkillsJson: targetSkillsJson,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int accountId,
            required String name,
            Value<bool> banned = const Value.absent(),
            Value<String> actualSkillsJson = const Value.absent(),
            Value<String> targetSkillsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> lastUpdated = const Value.absent(),
          }) =>
              CharactersTableCompanion.insert(
            id: id,
            accountId: accountId,
            name: name,
            banned: banned,
            actualSkillsJson: actualSkillsJson,
            targetSkillsJson: targetSkillsJson,
            createdAt: createdAt,
            lastUpdated: lastUpdated,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CharactersTableTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (accountId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.accountId,
                    referencedTable:
                        $$CharactersTableTableReferences._accountIdTable(db),
                    referencedColumn:
                        $$CharactersTableTableReferences._accountIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CharactersTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CharactersTableTable,
    CharactersTableData,
    $$CharactersTableTableFilterComposer,
    $$CharactersTableTableOrderingComposer,
    $$CharactersTableTableAnnotationComposer,
    $$CharactersTableTableCreateCompanionBuilder,
    $$CharactersTableTableUpdateCompanionBuilder,
    (CharactersTableData, $$CharactersTableTableReferences),
    CharactersTableData,
    PrefetchHooks Function({bool accountId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppConfigTableTableTableManager get appConfigTable =>
      $$AppConfigTableTableTableManager(_db, _db.appConfigTable);
  $$ProxySlotsTableTableTableManager get proxySlotsTable =>
      $$ProxySlotsTableTableTableManager(_db, _db.proxySlotsTable);
  $$ProxyIpAddressesTableTableTableManager get proxyIpAddressesTable =>
      $$ProxyIpAddressesTableTableTableManager(_db, _db.proxyIpAddressesTable);
  $$AccountsTableTableTableManager get accountsTable =>
      $$AccountsTableTableTableManager(_db, _db.accountsTable);
  $$CharactersTableTableTableManager get charactersTable =>
      $$CharactersTableTableTableManager(_db, _db.charactersTable);
}
