// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppMetaTable extends AppMeta with TableInfo<$AppMetaTable, AppMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaData extends DataClass implements Insertable<AppMetaData> {
  final String key;
  final String value;
  const AppMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(key: Value(key), value: Value(value));
  }

  factory AppMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetaData copyWith({String? key, String? value}) =>
      AppMetaData(key: key ?? this.key, value: value ?? this.value);
  AppMetaData copyWithCompanion(AppMetaCompanion data) {
    return AppMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final String key;
  final String value;
  const UserSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory UserSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  UserSetting copyWith({String? key, String? value}) =>
      UserSetting(key: key ?? this.key, value: value ?? this.value);
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const UserSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<UserSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return UserSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitsTable extends Habits with TableInfo<$HabitsTable, Habit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateKeyMeta = const VerificationMeta(
    'templateKey',
  );
  @override
  late final GeneratedColumn<String> templateKey = GeneratedColumn<String>(
    'template_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalKeyMeta = const VerificationMeta(
    'goalKey',
  );
  @override
  late final GeneratedColumn<String> goalKey = GeneratedColumn<String>(
    'goal_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaKeyMeta = const VerificationMeta(
    'areaKey',
  );
  @override
  late final GeneratedColumn<String> areaKey = GeneratedColumn<String>(
    'area_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeOfDayMeta = const VerificationMeta(
    'timeOfDay',
  );
  @override
  late final GeneratedColumn<String> timeOfDay = GeneratedColumn<String>(
    'time_of_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('any'),
  );
  static const VerificationMeta _repeatTypeMeta = const VerificationMeta(
    'repeatType',
  );
  @override
  late final GeneratedColumn<String> repeatType = GeneratedColumn<String>(
    'repeat_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('daily'),
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<String> dueDay = GeneratedColumn<String>(
    'due_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('check'),
  );
  static const VerificationMeta _scheduleTypeMeta = const VerificationMeta(
    'scheduleType',
  );
  @override
  late final GeneratedColumn<String> scheduleType = GeneratedColumn<String>(
    'schedule_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('daily'),
  );
  static const VerificationMeta _weekdaysMaskMeta = const VerificationMeta(
    'weekdaysMask',
  );
  @override
  late final GeneratedColumn<int> weekdaysMask = GeneratedColumn<int>(
    'weekdays_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(127),
  );
  static const VerificationMeta _targetPerDayMeta = const VerificationMeta(
    'targetPerDay',
  );
  @override
  late final GeneratedColumn<int> targetPerDay = GeneratedColumn<int>(
    'target_per_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _reminderMinutesMeta = const VerificationMeta(
    'reminderMinutes',
  );
  @override
  late final GeneratedColumn<int> reminderMinutes = GeneratedColumn<int>(
    'reminder_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isLockedMeta = const VerificationMeta(
    'isLocked',
  );
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
    'is_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateKey,
    goalKey,
    areaKey,
    timeOfDay,
    repeatType,
    dueDay,
    title,
    icon,
    scheduleType,
    weekdaysMask,
    targetPerDay,
    reminderMinutes,
    isCustom,
    isLocked,
    archivedAt,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<Habit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('template_key')) {
      context.handle(
        _templateKeyMeta,
        templateKey.isAcceptableOrUnknown(
          data['template_key']!,
          _templateKeyMeta,
        ),
      );
    }
    if (data.containsKey('goal_key')) {
      context.handle(
        _goalKeyMeta,
        goalKey.isAcceptableOrUnknown(data['goal_key']!, _goalKeyMeta),
      );
    }
    if (data.containsKey('area_key')) {
      context.handle(
        _areaKeyMeta,
        areaKey.isAcceptableOrUnknown(data['area_key']!, _areaKeyMeta),
      );
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
        _timeOfDayMeta,
        timeOfDay.isAcceptableOrUnknown(data['time_of_day']!, _timeOfDayMeta),
      );
    }
    if (data.containsKey('repeat_type')) {
      context.handle(
        _repeatTypeMeta,
        repeatType.isAcceptableOrUnknown(data['repeat_type']!, _repeatTypeMeta),
      );
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('schedule_type')) {
      context.handle(
        _scheduleTypeMeta,
        scheduleType.isAcceptableOrUnknown(
          data['schedule_type']!,
          _scheduleTypeMeta,
        ),
      );
    }
    if (data.containsKey('weekdays_mask')) {
      context.handle(
        _weekdaysMaskMeta,
        weekdaysMask.isAcceptableOrUnknown(
          data['weekdays_mask']!,
          _weekdaysMaskMeta,
        ),
      );
    }
    if (data.containsKey('target_per_day')) {
      context.handle(
        _targetPerDayMeta,
        targetPerDay.isAcceptableOrUnknown(
          data['target_per_day']!,
          _targetPerDayMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minutes')) {
      context.handle(
        _reminderMinutesMeta,
        reminderMinutes.isAcceptableOrUnknown(
          data['reminder_minutes']!,
          _reminderMinutesMeta,
        ),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('is_locked')) {
      context.handle(
        _isLockedMeta,
        isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Habit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Habit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      templateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_key'],
      ),
      goalKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_key'],
      ),
      areaKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area_key'],
      ),
      timeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_of_day'],
      )!,
      repeatType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_type'],
      )!,
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_day'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      scheduleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_type'],
      )!,
      weekdaysMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekdays_mask'],
      )!,
      targetPerDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_per_day'],
      )!,
      reminderMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes'],
      ),
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      isLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_locked'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class Habit extends DataClass implements Insertable<Habit> {
  final String id;
  final String? templateKey;
  final String? goalKey;
  final String? areaKey;
  final String timeOfDay;
  final String repeatType;
  final String? dueDay;
  final String? title;
  final String icon;
  final String scheduleType;
  final int weekdaysMask;
  final int targetPerDay;
  final int? reminderMinutes;
  final bool isCustom;
  final bool isLocked;
  final int? archivedAt;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const Habit({
    required this.id,
    this.templateKey,
    this.goalKey,
    this.areaKey,
    required this.timeOfDay,
    required this.repeatType,
    this.dueDay,
    this.title,
    required this.icon,
    required this.scheduleType,
    required this.weekdaysMask,
    required this.targetPerDay,
    this.reminderMinutes,
    required this.isCustom,
    required this.isLocked,
    this.archivedAt,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || templateKey != null) {
      map['template_key'] = Variable<String>(templateKey);
    }
    if (!nullToAbsent || goalKey != null) {
      map['goal_key'] = Variable<String>(goalKey);
    }
    if (!nullToAbsent || areaKey != null) {
      map['area_key'] = Variable<String>(areaKey);
    }
    map['time_of_day'] = Variable<String>(timeOfDay);
    map['repeat_type'] = Variable<String>(repeatType);
    if (!nullToAbsent || dueDay != null) {
      map['due_day'] = Variable<String>(dueDay);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['icon'] = Variable<String>(icon);
    map['schedule_type'] = Variable<String>(scheduleType);
    map['weekdays_mask'] = Variable<int>(weekdaysMask);
    map['target_per_day'] = Variable<int>(targetPerDay);
    if (!nullToAbsent || reminderMinutes != null) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    map['is_locked'] = Variable<bool>(isLocked);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      templateKey: templateKey == null && nullToAbsent
          ? const Value.absent()
          : Value(templateKey),
      goalKey: goalKey == null && nullToAbsent
          ? const Value.absent()
          : Value(goalKey),
      areaKey: areaKey == null && nullToAbsent
          ? const Value.absent()
          : Value(areaKey),
      timeOfDay: Value(timeOfDay),
      repeatType: Value(repeatType),
      dueDay: dueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDay),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      icon: Value(icon),
      scheduleType: Value(scheduleType),
      weekdaysMask: Value(weekdaysMask),
      targetPerDay: Value(targetPerDay),
      reminderMinutes: reminderMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutes),
      isCustom: Value(isCustom),
      isLocked: Value(isLocked),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Habit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Habit(
      id: serializer.fromJson<String>(json['id']),
      templateKey: serializer.fromJson<String?>(json['templateKey']),
      goalKey: serializer.fromJson<String?>(json['goalKey']),
      areaKey: serializer.fromJson<String?>(json['areaKey']),
      timeOfDay: serializer.fromJson<String>(json['timeOfDay']),
      repeatType: serializer.fromJson<String>(json['repeatType']),
      dueDay: serializer.fromJson<String?>(json['dueDay']),
      title: serializer.fromJson<String?>(json['title']),
      icon: serializer.fromJson<String>(json['icon']),
      scheduleType: serializer.fromJson<String>(json['scheduleType']),
      weekdaysMask: serializer.fromJson<int>(json['weekdaysMask']),
      targetPerDay: serializer.fromJson<int>(json['targetPerDay']),
      reminderMinutes: serializer.fromJson<int?>(json['reminderMinutes']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'templateKey': serializer.toJson<String?>(templateKey),
      'goalKey': serializer.toJson<String?>(goalKey),
      'areaKey': serializer.toJson<String?>(areaKey),
      'timeOfDay': serializer.toJson<String>(timeOfDay),
      'repeatType': serializer.toJson<String>(repeatType),
      'dueDay': serializer.toJson<String?>(dueDay),
      'title': serializer.toJson<String?>(title),
      'icon': serializer.toJson<String>(icon),
      'scheduleType': serializer.toJson<String>(scheduleType),
      'weekdaysMask': serializer.toJson<int>(weekdaysMask),
      'targetPerDay': serializer.toJson<int>(targetPerDay),
      'reminderMinutes': serializer.toJson<int?>(reminderMinutes),
      'isCustom': serializer.toJson<bool>(isCustom),
      'isLocked': serializer.toJson<bool>(isLocked),
      'archivedAt': serializer.toJson<int?>(archivedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Habit copyWith({
    String? id,
    Value<String?> templateKey = const Value.absent(),
    Value<String?> goalKey = const Value.absent(),
    Value<String?> areaKey = const Value.absent(),
    String? timeOfDay,
    String? repeatType,
    Value<String?> dueDay = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? icon,
    String? scheduleType,
    int? weekdaysMask,
    int? targetPerDay,
    Value<int?> reminderMinutes = const Value.absent(),
    bool? isCustom,
    bool? isLocked,
    Value<int?> archivedAt = const Value.absent(),
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Habit(
    id: id ?? this.id,
    templateKey: templateKey.present ? templateKey.value : this.templateKey,
    goalKey: goalKey.present ? goalKey.value : this.goalKey,
    areaKey: areaKey.present ? areaKey.value : this.areaKey,
    timeOfDay: timeOfDay ?? this.timeOfDay,
    repeatType: repeatType ?? this.repeatType,
    dueDay: dueDay.present ? dueDay.value : this.dueDay,
    title: title.present ? title.value : this.title,
    icon: icon ?? this.icon,
    scheduleType: scheduleType ?? this.scheduleType,
    weekdaysMask: weekdaysMask ?? this.weekdaysMask,
    targetPerDay: targetPerDay ?? this.targetPerDay,
    reminderMinutes: reminderMinutes.present
        ? reminderMinutes.value
        : this.reminderMinutes,
    isCustom: isCustom ?? this.isCustom,
    isLocked: isLocked ?? this.isLocked,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Habit copyWithCompanion(HabitsCompanion data) {
    return Habit(
      id: data.id.present ? data.id.value : this.id,
      templateKey: data.templateKey.present
          ? data.templateKey.value
          : this.templateKey,
      goalKey: data.goalKey.present ? data.goalKey.value : this.goalKey,
      areaKey: data.areaKey.present ? data.areaKey.value : this.areaKey,
      timeOfDay: data.timeOfDay.present ? data.timeOfDay.value : this.timeOfDay,
      repeatType: data.repeatType.present
          ? data.repeatType.value
          : this.repeatType,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      title: data.title.present ? data.title.value : this.title,
      icon: data.icon.present ? data.icon.value : this.icon,
      scheduleType: data.scheduleType.present
          ? data.scheduleType.value
          : this.scheduleType,
      weekdaysMask: data.weekdaysMask.present
          ? data.weekdaysMask.value
          : this.weekdaysMask,
      targetPerDay: data.targetPerDay.present
          ? data.targetPerDay.value
          : this.targetPerDay,
      reminderMinutes: data.reminderMinutes.present
          ? data.reminderMinutes.value
          : this.reminderMinutes,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Habit(')
          ..write('id: $id, ')
          ..write('templateKey: $templateKey, ')
          ..write('goalKey: $goalKey, ')
          ..write('areaKey: $areaKey, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('repeatType: $repeatType, ')
          ..write('dueDay: $dueDay, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('weekdaysMask: $weekdaysMask, ')
          ..write('targetPerDay: $targetPerDay, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('isCustom: $isCustom, ')
          ..write('isLocked: $isLocked, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateKey,
    goalKey,
    areaKey,
    timeOfDay,
    repeatType,
    dueDay,
    title,
    icon,
    scheduleType,
    weekdaysMask,
    targetPerDay,
    reminderMinutes,
    isCustom,
    isLocked,
    archivedAt,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Habit &&
          other.id == this.id &&
          other.templateKey == this.templateKey &&
          other.goalKey == this.goalKey &&
          other.areaKey == this.areaKey &&
          other.timeOfDay == this.timeOfDay &&
          other.repeatType == this.repeatType &&
          other.dueDay == this.dueDay &&
          other.title == this.title &&
          other.icon == this.icon &&
          other.scheduleType == this.scheduleType &&
          other.weekdaysMask == this.weekdaysMask &&
          other.targetPerDay == this.targetPerDay &&
          other.reminderMinutes == this.reminderMinutes &&
          other.isCustom == this.isCustom &&
          other.isLocked == this.isLocked &&
          other.archivedAt == this.archivedAt &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class HabitsCompanion extends UpdateCompanion<Habit> {
  final Value<String> id;
  final Value<String?> templateKey;
  final Value<String?> goalKey;
  final Value<String?> areaKey;
  final Value<String> timeOfDay;
  final Value<String> repeatType;
  final Value<String?> dueDay;
  final Value<String?> title;
  final Value<String> icon;
  final Value<String> scheduleType;
  final Value<int> weekdaysMask;
  final Value<int> targetPerDay;
  final Value<int?> reminderMinutes;
  final Value<bool> isCustom;
  final Value<bool> isLocked;
  final Value<int?> archivedAt;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.templateKey = const Value.absent(),
    this.goalKey = const Value.absent(),
    this.areaKey = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.repeatType = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.title = const Value.absent(),
    this.icon = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.weekdaysMask = const Value.absent(),
    this.targetPerDay = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitsCompanion.insert({
    required String id,
    this.templateKey = const Value.absent(),
    this.goalKey = const Value.absent(),
    this.areaKey = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.repeatType = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.title = const Value.absent(),
    this.icon = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.weekdaysMask = const Value.absent(),
    this.targetPerDay = const Value.absent(),
    this.reminderMinutes = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Habit> custom({
    Expression<String>? id,
    Expression<String>? templateKey,
    Expression<String>? goalKey,
    Expression<String>? areaKey,
    Expression<String>? timeOfDay,
    Expression<String>? repeatType,
    Expression<String>? dueDay,
    Expression<String>? title,
    Expression<String>? icon,
    Expression<String>? scheduleType,
    Expression<int>? weekdaysMask,
    Expression<int>? targetPerDay,
    Expression<int>? reminderMinutes,
    Expression<bool>? isCustom,
    Expression<bool>? isLocked,
    Expression<int>? archivedAt,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateKey != null) 'template_key': templateKey,
      if (goalKey != null) 'goal_key': goalKey,
      if (areaKey != null) 'area_key': areaKey,
      if (timeOfDay != null) 'time_of_day': timeOfDay,
      if (repeatType != null) 'repeat_type': repeatType,
      if (dueDay != null) 'due_day': dueDay,
      if (title != null) 'title': title,
      if (icon != null) 'icon': icon,
      if (scheduleType != null) 'schedule_type': scheduleType,
      if (weekdaysMask != null) 'weekdays_mask': weekdaysMask,
      if (targetPerDay != null) 'target_per_day': targetPerDay,
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
      if (isCustom != null) 'is_custom': isCustom,
      if (isLocked != null) 'is_locked': isLocked,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitsCompanion copyWith({
    Value<String>? id,
    Value<String?>? templateKey,
    Value<String?>? goalKey,
    Value<String?>? areaKey,
    Value<String>? timeOfDay,
    Value<String>? repeatType,
    Value<String?>? dueDay,
    Value<String?>? title,
    Value<String>? icon,
    Value<String>? scheduleType,
    Value<int>? weekdaysMask,
    Value<int>? targetPerDay,
    Value<int?>? reminderMinutes,
    Value<bool>? isCustom,
    Value<bool>? isLocked,
    Value<int?>? archivedAt,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      templateKey: templateKey ?? this.templateKey,
      goalKey: goalKey ?? this.goalKey,
      areaKey: areaKey ?? this.areaKey,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      repeatType: repeatType ?? this.repeatType,
      dueDay: dueDay ?? this.dueDay,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      scheduleType: scheduleType ?? this.scheduleType,
      weekdaysMask: weekdaysMask ?? this.weekdaysMask,
      targetPerDay: targetPerDay ?? this.targetPerDay,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isCustom: isCustom ?? this.isCustom,
      isLocked: isLocked ?? this.isLocked,
      archivedAt: archivedAt ?? this.archivedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (templateKey.present) {
      map['template_key'] = Variable<String>(templateKey.value);
    }
    if (goalKey.present) {
      map['goal_key'] = Variable<String>(goalKey.value);
    }
    if (areaKey.present) {
      map['area_key'] = Variable<String>(areaKey.value);
    }
    if (timeOfDay.present) {
      map['time_of_day'] = Variable<String>(timeOfDay.value);
    }
    if (repeatType.present) {
      map['repeat_type'] = Variable<String>(repeatType.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<String>(dueDay.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (scheduleType.present) {
      map['schedule_type'] = Variable<String>(scheduleType.value);
    }
    if (weekdaysMask.present) {
      map['weekdays_mask'] = Variable<int>(weekdaysMask.value);
    }
    if (targetPerDay.present) {
      map['target_per_day'] = Variable<int>(targetPerDay.value);
    }
    if (reminderMinutes.present) {
      map['reminder_minutes'] = Variable<int>(reminderMinutes.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('templateKey: $templateKey, ')
          ..write('goalKey: $goalKey, ')
          ..write('areaKey: $areaKey, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('repeatType: $repeatType, ')
          ..write('dueDay: $dueDay, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('weekdaysMask: $weekdaysMask, ')
          ..write('targetPerDay: $targetPerDay, ')
          ..write('reminderMinutes: $reminderMinutes, ')
          ..write('isCustom: $isCustom, ')
          ..write('isLocked: $isLocked, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitLogsTable extends HabitLogs
    with TableInfo<$HabitLogsTable, HabitLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES habits (id)',
    ),
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('app'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    localDay,
    count,
    completedAt,
    source,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {habitId, localDay},
  ];
  @override
  HabitLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $HabitLogsTable createAlias(String alias) {
    return $HabitLogsTable(attachedDatabase, alias);
  }
}

class HabitLog extends DataClass implements Insertable<HabitLog> {
  final String id;
  final String habitId;
  final String localDay;
  final int count;
  final int completedAt;
  final String source;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.localDay,
    required this.count,
    required this.completedAt,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['local_day'] = Variable<String>(localDay);
    map['count'] = Variable<int>(count);
    map['completed_at'] = Variable<int>(completedAt);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  HabitLogsCompanion toCompanion(bool nullToAbsent) {
    return HabitLogsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      localDay: Value(localDay),
      count: Value(count),
      completedAt: Value(completedAt),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory HabitLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitLog(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      localDay: serializer.fromJson<String>(json['localDay']),
      count: serializer.fromJson<int>(json['count']),
      completedAt: serializer.fromJson<int>(json['completedAt']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String>(habitId),
      'localDay': serializer.toJson<String>(localDay),
      'count': serializer.toJson<int>(count),
      'completedAt': serializer.toJson<int>(completedAt),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  HabitLog copyWith({
    String? id,
    String? habitId,
    String? localDay,
    int? count,
    int? completedAt,
    String? source,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => HabitLog(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    localDay: localDay ?? this.localDay,
    count: count ?? this.count,
    completedAt: completedAt ?? this.completedAt,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  HabitLog copyWithCompanion(HabitLogsCompanion data) {
    return HabitLog(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      count: data.count.present ? data.count.value : this.count,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitLog(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDay: $localDay, ')
          ..write('count: $count, ')
          ..write('completedAt: $completedAt, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    habitId,
    localDay,
    count,
    completedAt,
    source,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitLog &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.localDay == this.localDay &&
          other.count == this.count &&
          other.completedAt == this.completedAt &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class HabitLogsCompanion extends UpdateCompanion<HabitLog> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<String> localDay;
  final Value<int> count;
  final Value<int> completedAt;
  final Value<String> source;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const HabitLogsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.localDay = const Value.absent(),
    this.count = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitLogsCompanion.insert({
    required String id,
    required String habitId,
    required String localDay,
    this.count = const Value.absent(),
    required int completedAt,
    this.source = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       localDay = Value(localDay),
       completedAt = Value(completedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<HabitLog> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<String>? localDay,
    Expression<int>? count,
    Expression<int>? completedAt,
    Expression<String>? source,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (localDay != null) 'local_day': localDay,
      if (count != null) 'count': count,
      if (completedAt != null) 'completed_at': completedAt,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<String>? localDay,
    Value<int>? count,
    Value<int>? completedAt,
    Value<String>? source,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return HabitLogsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      localDay: localDay ?? this.localDay,
      count: count ?? this.count,
      completedAt: completedAt ?? this.completedAt,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitLogsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDay: $localDay, ')
          ..write('count: $count, ')
          ..write('completedAt: $completedAt, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CheckinsTable extends Checkins with TableInfo<$CheckinsTable, Checkin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckinsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodLevelMeta = const VerificationMeta(
    'moodLevel',
  );
  @override
  late final GeneratedColumn<int> moodLevel = GeneratedColumn<int>(
    'mood_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('app'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localDay,
    moodLevel,
    note,
    tags,
    source,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'checkins';
  @override
  VerificationContext validateIntegrity(
    Insertable<Checkin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('mood_level')) {
      context.handle(
        _moodLevelMeta,
        moodLevel.isAcceptableOrUnknown(data['mood_level']!, _moodLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_moodLevelMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Checkin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Checkin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      moodLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood_level'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CheckinsTable createAlias(String alias) {
    return $CheckinsTable(attachedDatabase, alias);
  }
}

class Checkin extends DataClass implements Insertable<Checkin> {
  final String id;
  final String localDay;
  final int moodLevel;
  final String? note;
  final String? tags;
  final String source;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const Checkin({
    required this.id,
    required this.localDay,
    required this.moodLevel,
    this.note,
    this.tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['local_day'] = Variable<String>(localDay);
    map['mood_level'] = Variable<int>(moodLevel);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  CheckinsCompanion toCompanion(bool nullToAbsent) {
    return CheckinsCompanion(
      id: Value(id),
      localDay: Value(localDay),
      moodLevel: Value(moodLevel),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Checkin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Checkin(
      id: serializer.fromJson<String>(json['id']),
      localDay: serializer.fromJson<String>(json['localDay']),
      moodLevel: serializer.fromJson<int>(json['moodLevel']),
      note: serializer.fromJson<String?>(json['note']),
      tags: serializer.fromJson<String?>(json['tags']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'localDay': serializer.toJson<String>(localDay),
      'moodLevel': serializer.toJson<int>(moodLevel),
      'note': serializer.toJson<String?>(note),
      'tags': serializer.toJson<String?>(tags),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  Checkin copyWith({
    String? id,
    String? localDay,
    int? moodLevel,
    Value<String?> note = const Value.absent(),
    Value<String?> tags = const Value.absent(),
    String? source,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => Checkin(
    id: id ?? this.id,
    localDay: localDay ?? this.localDay,
    moodLevel: moodLevel ?? this.moodLevel,
    note: note.present ? note.value : this.note,
    tags: tags.present ? tags.value : this.tags,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Checkin copyWithCompanion(CheckinsCompanion data) {
    return Checkin(
      id: data.id.present ? data.id.value : this.id,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      moodLevel: data.moodLevel.present ? data.moodLevel.value : this.moodLevel,
      note: data.note.present ? data.note.value : this.note,
      tags: data.tags.present ? data.tags.value : this.tags,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Checkin(')
          ..write('id: $id, ')
          ..write('localDay: $localDay, ')
          ..write('moodLevel: $moodLevel, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localDay,
    moodLevel,
    note,
    tags,
    source,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Checkin &&
          other.id == this.id &&
          other.localDay == this.localDay &&
          other.moodLevel == this.moodLevel &&
          other.note == this.note &&
          other.tags == this.tags &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CheckinsCompanion extends UpdateCompanion<Checkin> {
  final Value<String> id;
  final Value<String> localDay;
  final Value<int> moodLevel;
  final Value<String?> note;
  final Value<String?> tags;
  final Value<String> source;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const CheckinsCompanion({
    this.id = const Value.absent(),
    this.localDay = const Value.absent(),
    this.moodLevel = const Value.absent(),
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckinsCompanion.insert({
    required String id,
    required String localDay,
    required int moodLevel,
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    this.source = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localDay = Value(localDay),
       moodLevel = Value(moodLevel),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Checkin> custom({
    Expression<String>? id,
    Expression<String>? localDay,
    Expression<int>? moodLevel,
    Expression<String>? note,
    Expression<String>? tags,
    Expression<String>? source,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localDay != null) 'local_day': localDay,
      if (moodLevel != null) 'mood_level': moodLevel,
      if (note != null) 'note': note,
      if (tags != null) 'tags': tags,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckinsCompanion copyWith({
    Value<String>? id,
    Value<String>? localDay,
    Value<int>? moodLevel,
    Value<String?>? note,
    Value<String?>? tags,
    Value<String>? source,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CheckinsCompanion(
      id: id ?? this.id,
      localDay: localDay ?? this.localDay,
      moodLevel: moodLevel ?? this.moodLevel,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (moodLevel.present) {
      map['mood_level'] = Variable<int>(moodLevel.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckinsCompanion(')
          ..write('id: $id, ')
          ..write('localDay: $localDay, ')
          ..write('moodLevel: $moodLevel, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseSessionsTable extends ExerciseSessions
    with TableInfo<$ExerciseSessionsTable, ExerciseSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseKeyMeta = const VerificationMeta(
    'exerciseKey',
  );
  @override
  late final GeneratedColumn<String> exerciseKey = GeneratedColumn<String>(
    'exercise_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSMeta = const VerificationMeta(
    'durationS',
  );
  @override
  late final GeneratedColumn<int> durationS = GeneratedColumn<int>(
    'duration_s',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _journalTextMeta = const VerificationMeta(
    'journalText',
  );
  @override
  late final GeneratedColumn<String> journalText = GeneratedColumn<String>(
    'journal_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseKey,
    startedAt,
    completedAt,
    durationS,
    localDay,
    journalText,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exercise_key')) {
      context.handle(
        _exerciseKeyMeta,
        exerciseKey.isAcceptableOrUnknown(
          data['exercise_key']!,
          _exerciseKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseKeyMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('duration_s')) {
      context.handle(
        _durationSMeta,
        durationS.isAcceptableOrUnknown(data['duration_s']!, _durationSMeta),
      );
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('journal_text')) {
      context.handle(
        _journalTextMeta,
        journalText.isAcceptableOrUnknown(
          data['journal_text']!,
          _journalTextMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      exerciseKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_key'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      durationS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_s'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      journalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}journal_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ExerciseSessionsTable createAlias(String alias) {
    return $ExerciseSessionsTable(attachedDatabase, alias);
  }
}

class ExerciseSession extends DataClass implements Insertable<ExerciseSession> {
  final String id;
  final String exerciseKey;
  final int startedAt;
  final int? completedAt;
  final int durationS;
  final String localDay;
  final String? journalText;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  const ExerciseSession({
    required this.id,
    required this.exerciseKey,
    required this.startedAt,
    this.completedAt,
    required this.durationS,
    required this.localDay,
    this.journalText,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exercise_key'] = Variable<String>(exerciseKey);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['duration_s'] = Variable<int>(durationS);
    map['local_day'] = Variable<String>(localDay);
    if (!nullToAbsent || journalText != null) {
      map['journal_text'] = Variable<String>(journalText);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  ExerciseSessionsCompanion toCompanion(bool nullToAbsent) {
    return ExerciseSessionsCompanion(
      id: Value(id),
      exerciseKey: Value(exerciseKey),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      durationS: Value(durationS),
      localDay: Value(localDay),
      journalText: journalText == null && nullToAbsent
          ? const Value.absent()
          : Value(journalText),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ExerciseSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseSession(
      id: serializer.fromJson<String>(json['id']),
      exerciseKey: serializer.fromJson<String>(json['exerciseKey']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      durationS: serializer.fromJson<int>(json['durationS']),
      localDay: serializer.fromJson<String>(json['localDay']),
      journalText: serializer.fromJson<String?>(json['journalText']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'exerciseKey': serializer.toJson<String>(exerciseKey),
      'startedAt': serializer.toJson<int>(startedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'durationS': serializer.toJson<int>(durationS),
      'localDay': serializer.toJson<String>(localDay),
      'journalText': serializer.toJson<String?>(journalText),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  ExerciseSession copyWith({
    String? id,
    String? exerciseKey,
    int? startedAt,
    Value<int?> completedAt = const Value.absent(),
    int? durationS,
    String? localDay,
    Value<String?> journalText = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
  }) => ExerciseSession(
    id: id ?? this.id,
    exerciseKey: exerciseKey ?? this.exerciseKey,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    durationS: durationS ?? this.durationS,
    localDay: localDay ?? this.localDay,
    journalText: journalText.present ? journalText.value : this.journalText,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ExerciseSession copyWithCompanion(ExerciseSessionsCompanion data) {
    return ExerciseSession(
      id: data.id.present ? data.id.value : this.id,
      exerciseKey: data.exerciseKey.present
          ? data.exerciseKey.value
          : this.exerciseKey,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      durationS: data.durationS.present ? data.durationS.value : this.durationS,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      journalText: data.journalText.present
          ? data.journalText.value
          : this.journalText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSession(')
          ..write('id: $id, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationS: $durationS, ')
          ..write('localDay: $localDay, ')
          ..write('journalText: $journalText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    exerciseKey,
    startedAt,
    completedAt,
    durationS,
    localDay,
    journalText,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseSession &&
          other.id == this.id &&
          other.exerciseKey == this.exerciseKey &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.durationS == this.durationS &&
          other.localDay == this.localDay &&
          other.journalText == this.journalText &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ExerciseSessionsCompanion extends UpdateCompanion<ExerciseSession> {
  final Value<String> id;
  final Value<String> exerciseKey;
  final Value<int> startedAt;
  final Value<int?> completedAt;
  final Value<int> durationS;
  final Value<String> localDay;
  final Value<String?> journalText;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const ExerciseSessionsCompanion({
    this.id = const Value.absent(),
    this.exerciseKey = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.durationS = const Value.absent(),
    this.localDay = const Value.absent(),
    this.journalText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseSessionsCompanion.insert({
    required String id,
    required String exerciseKey,
    required int startedAt,
    this.completedAt = const Value.absent(),
    this.durationS = const Value.absent(),
    required String localDay,
    this.journalText = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       exerciseKey = Value(exerciseKey),
       startedAt = Value(startedAt),
       localDay = Value(localDay),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ExerciseSession> custom({
    Expression<String>? id,
    Expression<String>? exerciseKey,
    Expression<int>? startedAt,
    Expression<int>? completedAt,
    Expression<int>? durationS,
    Expression<String>? localDay,
    Expression<String>? journalText,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseKey != null) 'exercise_key': exerciseKey,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (durationS != null) 'duration_s': durationS,
      if (localDay != null) 'local_day': localDay,
      if (journalText != null) 'journal_text': journalText,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? exerciseKey,
    Value<int>? startedAt,
    Value<int?>? completedAt,
    Value<int>? durationS,
    Value<String>? localDay,
    Value<String?>? journalText,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ExerciseSessionsCompanion(
      id: id ?? this.id,
      exerciseKey: exerciseKey ?? this.exerciseKey,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationS: durationS ?? this.durationS,
      localDay: localDay ?? this.localDay,
      journalText: journalText ?? this.journalText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (exerciseKey.present) {
      map['exercise_key'] = Variable<String>(exerciseKey.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (durationS.present) {
      map['duration_s'] = Variable<int>(durationS.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (journalText.present) {
      map['journal_text'] = Variable<String>(journalText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseSessionsCompanion(')
          ..write('id: $id, ')
          ..write('exerciseKey: $exerciseKey, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('durationS: $durationS, ')
          ..write('localDay: $localDay, ')
          ..write('journalText: $journalText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletTable extends Wallet with TableInfo<$WalletTable, WalletData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energyMeta = const VerificationMeta('energy');
  @override
  late final GeneratedColumn<int> energy = GeneratedColumn<int>(
    'energy',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coinsMeta = const VerificationMeta('coins');
  @override
  late final GeneratedColumn<int> coins = GeneratedColumn<int>(
    'coins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, energy, coins, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('energy')) {
      context.handle(
        _energyMeta,
        energy.isAcceptableOrUnknown(data['energy']!, _energyMeta),
      );
    }
    if (data.containsKey('coins')) {
      context.handle(
        _coinsMeta,
        coins.isAcceptableOrUnknown(data['coins']!, _coinsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      energy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy'],
      )!,
      coins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WalletTable createAlias(String alias) {
    return $WalletTable(attachedDatabase, alias);
  }
}

class WalletData extends DataClass implements Insertable<WalletData> {
  final int id;
  final int energy;
  final int coins;
  final int updatedAt;
  const WalletData({
    required this.id,
    required this.energy,
    required this.coins,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['energy'] = Variable<int>(energy);
    map['coins'] = Variable<int>(coins);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  WalletCompanion toCompanion(bool nullToAbsent) {
    return WalletCompanion(
      id: Value(id),
      energy: Value(energy),
      coins: Value(coins),
      updatedAt: Value(updatedAt),
    );
  }

  factory WalletData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletData(
      id: serializer.fromJson<int>(json['id']),
      energy: serializer.fromJson<int>(json['energy']),
      coins: serializer.fromJson<int>(json['coins']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'energy': serializer.toJson<int>(energy),
      'coins': serializer.toJson<int>(coins),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  WalletData copyWith({int? id, int? energy, int? coins, int? updatedAt}) =>
      WalletData(
        id: id ?? this.id,
        energy: energy ?? this.energy,
        coins: coins ?? this.coins,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WalletData copyWithCompanion(WalletCompanion data) {
    return WalletData(
      id: data.id.present ? data.id.value : this.id,
      energy: data.energy.present ? data.energy.value : this.energy,
      coins: data.coins.present ? data.coins.value : this.coins,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletData(')
          ..write('id: $id, ')
          ..write('energy: $energy, ')
          ..write('coins: $coins, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, energy, coins, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletData &&
          other.id == this.id &&
          other.energy == this.energy &&
          other.coins == this.coins &&
          other.updatedAt == this.updatedAt);
}

class WalletCompanion extends UpdateCompanion<WalletData> {
  final Value<int> id;
  final Value<int> energy;
  final Value<int> coins;
  final Value<int> updatedAt;
  const WalletCompanion({
    this.id = const Value.absent(),
    this.energy = const Value.absent(),
    this.coins = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  WalletCompanion.insert({
    this.id = const Value.absent(),
    this.energy = const Value.absent(),
    this.coins = const Value.absent(),
    required int updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<WalletData> custom({
    Expression<int>? id,
    Expression<int>? energy,
    Expression<int>? coins,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (energy != null) 'energy': energy,
      if (coins != null) 'coins': coins,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  WalletCompanion copyWith({
    Value<int>? id,
    Value<int>? energy,
    Value<int>? coins,
    Value<int>? updatedAt,
  }) {
    return WalletCompanion(
      id: id ?? this.id,
      energy: energy ?? this.energy,
      coins: coins ?? this.coins,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (energy.present) {
      map['energy'] = Variable<int>(energy.value);
    }
    if (coins.present) {
      map['coins'] = Variable<int>(coins.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletCompanion(')
          ..write('id: $id, ')
          ..write('energy: $energy, ')
          ..write('coins: $coins, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WalletLedgerTable extends WalletLedger
    with TableInfo<$WalletLedgerTable, WalletLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletLedgerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  @override
  late final GeneratedColumn<int> delta = GeneratedColumn<int>(
    'delta',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  @override
  late final GeneratedColumn<String> refId = GeneratedColumn<String>(
    'ref_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currency,
    delta,
    reason,
    refId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletLedgerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
        _deltaMeta,
        delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta),
      );
    } else if (isInserting) {
      context.missing(_deltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
        _refIdMeta,
        refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta),
      );
    } else if (isInserting) {
      context.missing(_refIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {reason, refId},
  ];
  @override
  WalletLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletLedgerData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      delta: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delta'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      refId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WalletLedgerTable createAlias(String alias) {
    return $WalletLedgerTable(attachedDatabase, alias);
  }
}

class WalletLedgerData extends DataClass
    implements Insertable<WalletLedgerData> {
  final String id;
  final String currency;
  final int delta;
  final String reason;
  final String refId;
  final int createdAt;
  const WalletLedgerData({
    required this.id,
    required this.currency,
    required this.delta,
    required this.reason,
    required this.refId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['currency'] = Variable<String>(currency);
    map['delta'] = Variable<int>(delta);
    map['reason'] = Variable<String>(reason);
    map['ref_id'] = Variable<String>(refId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  WalletLedgerCompanion toCompanion(bool nullToAbsent) {
    return WalletLedgerCompanion(
      id: Value(id),
      currency: Value(currency),
      delta: Value(delta),
      reason: Value(reason),
      refId: Value(refId),
      createdAt: Value(createdAt),
    );
  }

  factory WalletLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletLedgerData(
      id: serializer.fromJson<String>(json['id']),
      currency: serializer.fromJson<String>(json['currency']),
      delta: serializer.fromJson<int>(json['delta']),
      reason: serializer.fromJson<String>(json['reason']),
      refId: serializer.fromJson<String>(json['refId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'currency': serializer.toJson<String>(currency),
      'delta': serializer.toJson<int>(delta),
      'reason': serializer.toJson<String>(reason),
      'refId': serializer.toJson<String>(refId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  WalletLedgerData copyWith({
    String? id,
    String? currency,
    int? delta,
    String? reason,
    String? refId,
    int? createdAt,
  }) => WalletLedgerData(
    id: id ?? this.id,
    currency: currency ?? this.currency,
    delta: delta ?? this.delta,
    reason: reason ?? this.reason,
    refId: refId ?? this.refId,
    createdAt: createdAt ?? this.createdAt,
  );
  WalletLedgerData copyWithCompanion(WalletLedgerCompanion data) {
    return WalletLedgerData(
      id: data.id.present ? data.id.value : this.id,
      currency: data.currency.present ? data.currency.value : this.currency,
      delta: data.delta.present ? data.delta.value : this.delta,
      reason: data.reason.present ? data.reason.value : this.reason,
      refId: data.refId.present ? data.refId.value : this.refId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletLedgerData(')
          ..write('id: $id, ')
          ..write('currency: $currency, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('refId: $refId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, currency, delta, reason, refId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletLedgerData &&
          other.id == this.id &&
          other.currency == this.currency &&
          other.delta == this.delta &&
          other.reason == this.reason &&
          other.refId == this.refId &&
          other.createdAt == this.createdAt);
}

class WalletLedgerCompanion extends UpdateCompanion<WalletLedgerData> {
  final Value<String> id;
  final Value<String> currency;
  final Value<int> delta;
  final Value<String> reason;
  final Value<String> refId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const WalletLedgerCompanion({
    this.id = const Value.absent(),
    this.currency = const Value.absent(),
    this.delta = const Value.absent(),
    this.reason = const Value.absent(),
    this.refId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletLedgerCompanion.insert({
    required String id,
    required String currency,
    required int delta,
    required String reason,
    required String refId,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       currency = Value(currency),
       delta = Value(delta),
       reason = Value(reason),
       refId = Value(refId),
       createdAt = Value(createdAt);
  static Insertable<WalletLedgerData> custom({
    Expression<String>? id,
    Expression<String>? currency,
    Expression<int>? delta,
    Expression<String>? reason,
    Expression<String>? refId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currency != null) 'currency': currency,
      if (delta != null) 'delta': delta,
      if (reason != null) 'reason': reason,
      if (refId != null) 'ref_id': refId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletLedgerCompanion copyWith({
    Value<String>? id,
    Value<String>? currency,
    Value<int>? delta,
    Value<String>? reason,
    Value<String>? refId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return WalletLedgerCompanion(
      id: id ?? this.id,
      currency: currency ?? this.currency,
      delta: delta ?? this.delta,
      reason: reason ?? this.reason,
      refId: refId ?? this.refId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (delta.present) {
      map['delta'] = Variable<int>(delta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<String>(refId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletLedgerCompanion(')
          ..write('id: $id, ')
          ..write('currency: $currency, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('refId: $refId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AdventuresTable extends Adventures
    with TableInfo<$AdventuresTable, Adventure> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdventuresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationKeyMeta = const VerificationMeta(
    'locationKey',
  );
  @override
  late final GeneratedColumn<String> locationKey = GeneratedColumn<String>(
    'location_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyCostMeta = const VerificationMeta(
    'energyCost',
  );
  @override
  late final GeneratedColumn<int> energyCost = GeneratedColumn<int>(
    'energy_cost',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<int> endsAt = GeneratedColumn<int>(
    'ends_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _rewardCoinsMeta = const VerificationMeta(
    'rewardCoins',
  );
  @override
  late final GeneratedColumn<int> rewardCoins = GeneratedColumn<int>(
    'reward_coins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rewardItemKeyMeta = const VerificationMeta(
    'rewardItemKey',
  );
  @override
  late final GeneratedColumn<String> rewardItemKey = GeneratedColumn<String>(
    'reward_item_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _storyKeyMeta = const VerificationMeta(
    'storyKey',
  );
  @override
  late final GeneratedColumn<String> storyKey = GeneratedColumn<String>(
    'story_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta(
    'claimedAt',
  );
  @override
  late final GeneratedColumn<int> claimedAt = GeneratedColumn<int>(
    'claimed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    locationKey,
    energyCost,
    startedAt,
    endsAt,
    status,
    rewardCoins,
    rewardItemKey,
    storyKey,
    claimedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'adventures';
  @override
  VerificationContext validateIntegrity(
    Insertable<Adventure> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('location_key')) {
      context.handle(
        _locationKeyMeta,
        locationKey.isAcceptableOrUnknown(
          data['location_key']!,
          _locationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_locationKeyMeta);
    }
    if (data.containsKey('energy_cost')) {
      context.handle(
        _energyCostMeta,
        energyCost.isAcceptableOrUnknown(data['energy_cost']!, _energyCostMeta),
      );
    } else if (isInserting) {
      context.missing(_energyCostMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endsAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('reward_coins')) {
      context.handle(
        _rewardCoinsMeta,
        rewardCoins.isAcceptableOrUnknown(
          data['reward_coins']!,
          _rewardCoinsMeta,
        ),
      );
    }
    if (data.containsKey('reward_item_key')) {
      context.handle(
        _rewardItemKeyMeta,
        rewardItemKey.isAcceptableOrUnknown(
          data['reward_item_key']!,
          _rewardItemKeyMeta,
        ),
      );
    }
    if (data.containsKey('story_key')) {
      context.handle(
        _storyKeyMeta,
        storyKey.isAcceptableOrUnknown(data['story_key']!, _storyKeyMeta),
      );
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Adventure map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Adventure(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      locationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_key'],
      )!,
      energyCost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy_cost'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ends_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rewardCoins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reward_coins'],
      )!,
      rewardItemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reward_item_key'],
      ),
      storyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}story_key'],
      ),
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}claimed_at'],
      ),
    );
  }

  @override
  $AdventuresTable createAlias(String alias) {
    return $AdventuresTable(attachedDatabase, alias);
  }
}

class Adventure extends DataClass implements Insertable<Adventure> {
  final String id;
  final String locationKey;
  final int energyCost;
  final int startedAt;
  final int endsAt;
  final String status;
  final int rewardCoins;
  final String? rewardItemKey;
  final String? storyKey;
  final int? claimedAt;
  const Adventure({
    required this.id,
    required this.locationKey,
    required this.energyCost,
    required this.startedAt,
    required this.endsAt,
    required this.status,
    required this.rewardCoins,
    this.rewardItemKey,
    this.storyKey,
    this.claimedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['location_key'] = Variable<String>(locationKey);
    map['energy_cost'] = Variable<int>(energyCost);
    map['started_at'] = Variable<int>(startedAt);
    map['ends_at'] = Variable<int>(endsAt);
    map['status'] = Variable<String>(status);
    map['reward_coins'] = Variable<int>(rewardCoins);
    if (!nullToAbsent || rewardItemKey != null) {
      map['reward_item_key'] = Variable<String>(rewardItemKey);
    }
    if (!nullToAbsent || storyKey != null) {
      map['story_key'] = Variable<String>(storyKey);
    }
    if (!nullToAbsent || claimedAt != null) {
      map['claimed_at'] = Variable<int>(claimedAt);
    }
    return map;
  }

  AdventuresCompanion toCompanion(bool nullToAbsent) {
    return AdventuresCompanion(
      id: Value(id),
      locationKey: Value(locationKey),
      energyCost: Value(energyCost),
      startedAt: Value(startedAt),
      endsAt: Value(endsAt),
      status: Value(status),
      rewardCoins: Value(rewardCoins),
      rewardItemKey: rewardItemKey == null && nullToAbsent
          ? const Value.absent()
          : Value(rewardItemKey),
      storyKey: storyKey == null && nullToAbsent
          ? const Value.absent()
          : Value(storyKey),
      claimedAt: claimedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(claimedAt),
    );
  }

  factory Adventure.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Adventure(
      id: serializer.fromJson<String>(json['id']),
      locationKey: serializer.fromJson<String>(json['locationKey']),
      energyCost: serializer.fromJson<int>(json['energyCost']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endsAt: serializer.fromJson<int>(json['endsAt']),
      status: serializer.fromJson<String>(json['status']),
      rewardCoins: serializer.fromJson<int>(json['rewardCoins']),
      rewardItemKey: serializer.fromJson<String?>(json['rewardItemKey']),
      storyKey: serializer.fromJson<String?>(json['storyKey']),
      claimedAt: serializer.fromJson<int?>(json['claimedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'locationKey': serializer.toJson<String>(locationKey),
      'energyCost': serializer.toJson<int>(energyCost),
      'startedAt': serializer.toJson<int>(startedAt),
      'endsAt': serializer.toJson<int>(endsAt),
      'status': serializer.toJson<String>(status),
      'rewardCoins': serializer.toJson<int>(rewardCoins),
      'rewardItemKey': serializer.toJson<String?>(rewardItemKey),
      'storyKey': serializer.toJson<String?>(storyKey),
      'claimedAt': serializer.toJson<int?>(claimedAt),
    };
  }

  Adventure copyWith({
    String? id,
    String? locationKey,
    int? energyCost,
    int? startedAt,
    int? endsAt,
    String? status,
    int? rewardCoins,
    Value<String?> rewardItemKey = const Value.absent(),
    Value<String?> storyKey = const Value.absent(),
    Value<int?> claimedAt = const Value.absent(),
  }) => Adventure(
    id: id ?? this.id,
    locationKey: locationKey ?? this.locationKey,
    energyCost: energyCost ?? this.energyCost,
    startedAt: startedAt ?? this.startedAt,
    endsAt: endsAt ?? this.endsAt,
    status: status ?? this.status,
    rewardCoins: rewardCoins ?? this.rewardCoins,
    rewardItemKey: rewardItemKey.present
        ? rewardItemKey.value
        : this.rewardItemKey,
    storyKey: storyKey.present ? storyKey.value : this.storyKey,
    claimedAt: claimedAt.present ? claimedAt.value : this.claimedAt,
  );
  Adventure copyWithCompanion(AdventuresCompanion data) {
    return Adventure(
      id: data.id.present ? data.id.value : this.id,
      locationKey: data.locationKey.present
          ? data.locationKey.value
          : this.locationKey,
      energyCost: data.energyCost.present
          ? data.energyCost.value
          : this.energyCost,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      status: data.status.present ? data.status.value : this.status,
      rewardCoins: data.rewardCoins.present
          ? data.rewardCoins.value
          : this.rewardCoins,
      rewardItemKey: data.rewardItemKey.present
          ? data.rewardItemKey.value
          : this.rewardItemKey,
      storyKey: data.storyKey.present ? data.storyKey.value : this.storyKey,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Adventure(')
          ..write('id: $id, ')
          ..write('locationKey: $locationKey, ')
          ..write('energyCost: $energyCost, ')
          ..write('startedAt: $startedAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('status: $status, ')
          ..write('rewardCoins: $rewardCoins, ')
          ..write('rewardItemKey: $rewardItemKey, ')
          ..write('storyKey: $storyKey, ')
          ..write('claimedAt: $claimedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    locationKey,
    energyCost,
    startedAt,
    endsAt,
    status,
    rewardCoins,
    rewardItemKey,
    storyKey,
    claimedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Adventure &&
          other.id == this.id &&
          other.locationKey == this.locationKey &&
          other.energyCost == this.energyCost &&
          other.startedAt == this.startedAt &&
          other.endsAt == this.endsAt &&
          other.status == this.status &&
          other.rewardCoins == this.rewardCoins &&
          other.rewardItemKey == this.rewardItemKey &&
          other.storyKey == this.storyKey &&
          other.claimedAt == this.claimedAt);
}

class AdventuresCompanion extends UpdateCompanion<Adventure> {
  final Value<String> id;
  final Value<String> locationKey;
  final Value<int> energyCost;
  final Value<int> startedAt;
  final Value<int> endsAt;
  final Value<String> status;
  final Value<int> rewardCoins;
  final Value<String?> rewardItemKey;
  final Value<String?> storyKey;
  final Value<int?> claimedAt;
  final Value<int> rowid;
  const AdventuresCompanion({
    this.id = const Value.absent(),
    this.locationKey = const Value.absent(),
    this.energyCost = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rewardCoins = const Value.absent(),
    this.rewardItemKey = const Value.absent(),
    this.storyKey = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AdventuresCompanion.insert({
    required String id,
    required String locationKey,
    required int energyCost,
    required int startedAt,
    required int endsAt,
    this.status = const Value.absent(),
    this.rewardCoins = const Value.absent(),
    this.rewardItemKey = const Value.absent(),
    this.storyKey = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       locationKey = Value(locationKey),
       energyCost = Value(energyCost),
       startedAt = Value(startedAt),
       endsAt = Value(endsAt);
  static Insertable<Adventure> custom({
    Expression<String>? id,
    Expression<String>? locationKey,
    Expression<int>? energyCost,
    Expression<int>? startedAt,
    Expression<int>? endsAt,
    Expression<String>? status,
    Expression<int>? rewardCoins,
    Expression<String>? rewardItemKey,
    Expression<String>? storyKey,
    Expression<int>? claimedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (locationKey != null) 'location_key': locationKey,
      if (energyCost != null) 'energy_cost': energyCost,
      if (startedAt != null) 'started_at': startedAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (status != null) 'status': status,
      if (rewardCoins != null) 'reward_coins': rewardCoins,
      if (rewardItemKey != null) 'reward_item_key': rewardItemKey,
      if (storyKey != null) 'story_key': storyKey,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AdventuresCompanion copyWith({
    Value<String>? id,
    Value<String>? locationKey,
    Value<int>? energyCost,
    Value<int>? startedAt,
    Value<int>? endsAt,
    Value<String>? status,
    Value<int>? rewardCoins,
    Value<String?>? rewardItemKey,
    Value<String?>? storyKey,
    Value<int?>? claimedAt,
    Value<int>? rowid,
  }) {
    return AdventuresCompanion(
      id: id ?? this.id,
      locationKey: locationKey ?? this.locationKey,
      energyCost: energyCost ?? this.energyCost,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      rewardItemKey: rewardItemKey ?? this.rewardItemKey,
      storyKey: storyKey ?? this.storyKey,
      claimedAt: claimedAt ?? this.claimedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (locationKey.present) {
      map['location_key'] = Variable<String>(locationKey.value);
    }
    if (energyCost.present) {
      map['energy_cost'] = Variable<int>(energyCost.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<int>(endsAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rewardCoins.present) {
      map['reward_coins'] = Variable<int>(rewardCoins.value);
    }
    if (rewardItemKey.present) {
      map['reward_item_key'] = Variable<String>(rewardItemKey.value);
    }
    if (storyKey.present) {
      map['story_key'] = Variable<String>(storyKey.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<int>(claimedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdventuresCompanion(')
          ..write('id: $id, ')
          ..write('locationKey: $locationKey, ')
          ..write('energyCost: $energyCost, ')
          ..write('startedAt: $startedAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('status: $status, ')
          ..write('rewardCoins: $rewardCoins, ')
          ..write('rewardItemKey: $rewardItemKey, ')
          ..write('storyKey: $storyKey, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryTable extends Inventory
    with TableInfo<$InventoryTable, InventoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acquiredAtMeta = const VerificationMeta(
    'acquiredAt',
  );
  @override
  late final GeneratedColumn<int> acquiredAt = GeneratedColumn<int>(
    'acquired_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equippedMeta = const VerificationMeta(
    'equipped',
  );
  @override
  late final GeneratedColumn<bool> equipped = GeneratedColumn<bool>(
    'equipped',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("equipped" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemKey,
    acquiredAt,
    source,
    equipped,
    slot,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory';
  @override
  VerificationContext validateIntegrity(
    Insertable<InventoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    if (data.containsKey('acquired_at')) {
      context.handle(
        _acquiredAtMeta,
        acquiredAt.isAcceptableOrUnknown(data['acquired_at']!, _acquiredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_acquiredAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('equipped')) {
      context.handle(
        _equippedMeta,
        equipped.isAcceptableOrUnknown(data['equipped']!, _equippedMeta),
      );
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemKey};
  @override
  InventoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryData(
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      acquiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acquired_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      equipped: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}equipped'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
    );
  }

  @override
  $InventoryTable createAlias(String alias) {
    return $InventoryTable(attachedDatabase, alias);
  }
}

class InventoryData extends DataClass implements Insertable<InventoryData> {
  final String itemKey;
  final int acquiredAt;
  final String source;
  final bool equipped;
  final String slot;
  const InventoryData({
    required this.itemKey,
    required this.acquiredAt,
    required this.source,
    required this.equipped,
    required this.slot,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_key'] = Variable<String>(itemKey);
    map['acquired_at'] = Variable<int>(acquiredAt);
    map['source'] = Variable<String>(source);
    map['equipped'] = Variable<bool>(equipped);
    map['slot'] = Variable<String>(slot);
    return map;
  }

  InventoryCompanion toCompanion(bool nullToAbsent) {
    return InventoryCompanion(
      itemKey: Value(itemKey),
      acquiredAt: Value(acquiredAt),
      source: Value(source),
      equipped: Value(equipped),
      slot: Value(slot),
    );
  }

  factory InventoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryData(
      itemKey: serializer.fromJson<String>(json['itemKey']),
      acquiredAt: serializer.fromJson<int>(json['acquiredAt']),
      source: serializer.fromJson<String>(json['source']),
      equipped: serializer.fromJson<bool>(json['equipped']),
      slot: serializer.fromJson<String>(json['slot']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemKey': serializer.toJson<String>(itemKey),
      'acquiredAt': serializer.toJson<int>(acquiredAt),
      'source': serializer.toJson<String>(source),
      'equipped': serializer.toJson<bool>(equipped),
      'slot': serializer.toJson<String>(slot),
    };
  }

  InventoryData copyWith({
    String? itemKey,
    int? acquiredAt,
    String? source,
    bool? equipped,
    String? slot,
  }) => InventoryData(
    itemKey: itemKey ?? this.itemKey,
    acquiredAt: acquiredAt ?? this.acquiredAt,
    source: source ?? this.source,
    equipped: equipped ?? this.equipped,
    slot: slot ?? this.slot,
  );
  InventoryData copyWithCompanion(InventoryCompanion data) {
    return InventoryData(
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      acquiredAt: data.acquiredAt.present
          ? data.acquiredAt.value
          : this.acquiredAt,
      source: data.source.present ? data.source.value : this.source,
      equipped: data.equipped.present ? data.equipped.value : this.equipped,
      slot: data.slot.present ? data.slot.value : this.slot,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryData(')
          ..write('itemKey: $itemKey, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('source: $source, ')
          ..write('equipped: $equipped, ')
          ..write('slot: $slot')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemKey, acquiredAt, source, equipped, slot);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryData &&
          other.itemKey == this.itemKey &&
          other.acquiredAt == this.acquiredAt &&
          other.source == this.source &&
          other.equipped == this.equipped &&
          other.slot == this.slot);
}

class InventoryCompanion extends UpdateCompanion<InventoryData> {
  final Value<String> itemKey;
  final Value<int> acquiredAt;
  final Value<String> source;
  final Value<bool> equipped;
  final Value<String> slot;
  final Value<int> rowid;
  const InventoryCompanion({
    this.itemKey = const Value.absent(),
    this.acquiredAt = const Value.absent(),
    this.source = const Value.absent(),
    this.equipped = const Value.absent(),
    this.slot = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryCompanion.insert({
    required String itemKey,
    required int acquiredAt,
    required String source,
    this.equipped = const Value.absent(),
    required String slot,
    this.rowid = const Value.absent(),
  }) : itemKey = Value(itemKey),
       acquiredAt = Value(acquiredAt),
       source = Value(source),
       slot = Value(slot);
  static Insertable<InventoryData> custom({
    Expression<String>? itemKey,
    Expression<int>? acquiredAt,
    Expression<String>? source,
    Expression<bool>? equipped,
    Expression<String>? slot,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemKey != null) 'item_key': itemKey,
      if (acquiredAt != null) 'acquired_at': acquiredAt,
      if (source != null) 'source': source,
      if (equipped != null) 'equipped': equipped,
      if (slot != null) 'slot': slot,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryCompanion copyWith({
    Value<String>? itemKey,
    Value<int>? acquiredAt,
    Value<String>? source,
    Value<bool>? equipped,
    Value<String>? slot,
    Value<int>? rowid,
  }) {
    return InventoryCompanion(
      itemKey: itemKey ?? this.itemKey,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      source: source ?? this.source,
      equipped: equipped ?? this.equipped,
      slot: slot ?? this.slot,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (acquiredAt.present) {
      map['acquired_at'] = Variable<int>(acquiredAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (equipped.present) {
      map['equipped'] = Variable<bool>(equipped.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryCompanion(')
          ..write('itemKey: $itemKey, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('source: $source, ')
          ..write('equipped: $equipped, ')
          ..write('slot: $slot, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreakStateTable extends StreakState
    with TableInfo<$StreakStateTable, StreakStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentMeta = const VerificationMeta(
    'current',
  );
  @override
  late final GeneratedColumn<int> current = GeneratedColumn<int>(
    'current',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestMeta = const VerificationMeta(
    'longest',
  );
  @override
  late final GeneratedColumn<int> longest = GeneratedColumn<int>(
    'longest',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastActiveDayMeta = const VerificationMeta(
    'lastActiveDay',
  );
  @override
  late final GeneratedColumn<String> lastActiveDay = GeneratedColumn<String>(
    'last_active_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _freezesLeftMeta = const VerificationMeta(
    'freezesLeft',
  );
  @override
  late final GeneratedColumn<int> freezesLeft = GeneratedColumn<int>(
    'freezes_left',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _freezeMonthMeta = const VerificationMeta(
    'freezeMonth',
  );
  @override
  late final GeneratedColumn<String> freezeMonth = GeneratedColumn<String>(
    'freeze_month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    current,
    longest,
    lastActiveDay,
    freezesLeft,
    freezeMonth,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<StreakStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current')) {
      context.handle(
        _currentMeta,
        current.isAcceptableOrUnknown(data['current']!, _currentMeta),
      );
    }
    if (data.containsKey('longest')) {
      context.handle(
        _longestMeta,
        longest.isAcceptableOrUnknown(data['longest']!, _longestMeta),
      );
    }
    if (data.containsKey('last_active_day')) {
      context.handle(
        _lastActiveDayMeta,
        lastActiveDay.isAcceptableOrUnknown(
          data['last_active_day']!,
          _lastActiveDayMeta,
        ),
      );
    }
    if (data.containsKey('freezes_left')) {
      context.handle(
        _freezesLeftMeta,
        freezesLeft.isAcceptableOrUnknown(
          data['freezes_left']!,
          _freezesLeftMeta,
        ),
      );
    }
    if (data.containsKey('freeze_month')) {
      context.handle(
        _freezeMonthMeta,
        freezeMonth.isAcceptableOrUnknown(
          data['freeze_month']!,
          _freezeMonthMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StreakStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      current: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current'],
      )!,
      longest: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest'],
      )!,
      lastActiveDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_active_day'],
      ),
      freezesLeft: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}freezes_left'],
      )!,
      freezeMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}freeze_month'],
      ),
    );
  }

  @override
  $StreakStateTable createAlias(String alias) {
    return $StreakStateTable(attachedDatabase, alias);
  }
}

class StreakStateData extends DataClass implements Insertable<StreakStateData> {
  final int id;
  final int current;
  final int longest;
  final String? lastActiveDay;
  final int freezesLeft;
  final String? freezeMonth;
  const StreakStateData({
    required this.id,
    required this.current,
    required this.longest,
    this.lastActiveDay,
    required this.freezesLeft,
    this.freezeMonth,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current'] = Variable<int>(current);
    map['longest'] = Variable<int>(longest);
    if (!nullToAbsent || lastActiveDay != null) {
      map['last_active_day'] = Variable<String>(lastActiveDay);
    }
    map['freezes_left'] = Variable<int>(freezesLeft);
    if (!nullToAbsent || freezeMonth != null) {
      map['freeze_month'] = Variable<String>(freezeMonth);
    }
    return map;
  }

  StreakStateCompanion toCompanion(bool nullToAbsent) {
    return StreakStateCompanion(
      id: Value(id),
      current: Value(current),
      longest: Value(longest),
      lastActiveDay: lastActiveDay == null && nullToAbsent
          ? const Value.absent()
          : Value(lastActiveDay),
      freezesLeft: Value(freezesLeft),
      freezeMonth: freezeMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(freezeMonth),
    );
  }

  factory StreakStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakStateData(
      id: serializer.fromJson<int>(json['id']),
      current: serializer.fromJson<int>(json['current']),
      longest: serializer.fromJson<int>(json['longest']),
      lastActiveDay: serializer.fromJson<String?>(json['lastActiveDay']),
      freezesLeft: serializer.fromJson<int>(json['freezesLeft']),
      freezeMonth: serializer.fromJson<String?>(json['freezeMonth']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'current': serializer.toJson<int>(current),
      'longest': serializer.toJson<int>(longest),
      'lastActiveDay': serializer.toJson<String?>(lastActiveDay),
      'freezesLeft': serializer.toJson<int>(freezesLeft),
      'freezeMonth': serializer.toJson<String?>(freezeMonth),
    };
  }

  StreakStateData copyWith({
    int? id,
    int? current,
    int? longest,
    Value<String?> lastActiveDay = const Value.absent(),
    int? freezesLeft,
    Value<String?> freezeMonth = const Value.absent(),
  }) => StreakStateData(
    id: id ?? this.id,
    current: current ?? this.current,
    longest: longest ?? this.longest,
    lastActiveDay: lastActiveDay.present
        ? lastActiveDay.value
        : this.lastActiveDay,
    freezesLeft: freezesLeft ?? this.freezesLeft,
    freezeMonth: freezeMonth.present ? freezeMonth.value : this.freezeMonth,
  );
  StreakStateData copyWithCompanion(StreakStateCompanion data) {
    return StreakStateData(
      id: data.id.present ? data.id.value : this.id,
      current: data.current.present ? data.current.value : this.current,
      longest: data.longest.present ? data.longest.value : this.longest,
      lastActiveDay: data.lastActiveDay.present
          ? data.lastActiveDay.value
          : this.lastActiveDay,
      freezesLeft: data.freezesLeft.present
          ? data.freezesLeft.value
          : this.freezesLeft,
      freezeMonth: data.freezeMonth.present
          ? data.freezeMonth.value
          : this.freezeMonth,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StreakStateData(')
          ..write('id: $id, ')
          ..write('current: $current, ')
          ..write('longest: $longest, ')
          ..write('lastActiveDay: $lastActiveDay, ')
          ..write('freezesLeft: $freezesLeft, ')
          ..write('freezeMonth: $freezeMonth')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    current,
    longest,
    lastActiveDay,
    freezesLeft,
    freezeMonth,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakStateData &&
          other.id == this.id &&
          other.current == this.current &&
          other.longest == this.longest &&
          other.lastActiveDay == this.lastActiveDay &&
          other.freezesLeft == this.freezesLeft &&
          other.freezeMonth == this.freezeMonth);
}

class StreakStateCompanion extends UpdateCompanion<StreakStateData> {
  final Value<int> id;
  final Value<int> current;
  final Value<int> longest;
  final Value<String?> lastActiveDay;
  final Value<int> freezesLeft;
  final Value<String?> freezeMonth;
  const StreakStateCompanion({
    this.id = const Value.absent(),
    this.current = const Value.absent(),
    this.longest = const Value.absent(),
    this.lastActiveDay = const Value.absent(),
    this.freezesLeft = const Value.absent(),
    this.freezeMonth = const Value.absent(),
  });
  StreakStateCompanion.insert({
    this.id = const Value.absent(),
    this.current = const Value.absent(),
    this.longest = const Value.absent(),
    this.lastActiveDay = const Value.absent(),
    this.freezesLeft = const Value.absent(),
    this.freezeMonth = const Value.absent(),
  });
  static Insertable<StreakStateData> custom({
    Expression<int>? id,
    Expression<int>? current,
    Expression<int>? longest,
    Expression<String>? lastActiveDay,
    Expression<int>? freezesLeft,
    Expression<String>? freezeMonth,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (current != null) 'current': current,
      if (longest != null) 'longest': longest,
      if (lastActiveDay != null) 'last_active_day': lastActiveDay,
      if (freezesLeft != null) 'freezes_left': freezesLeft,
      if (freezeMonth != null) 'freeze_month': freezeMonth,
    });
  }

  StreakStateCompanion copyWith({
    Value<int>? id,
    Value<int>? current,
    Value<int>? longest,
    Value<String?>? lastActiveDay,
    Value<int>? freezesLeft,
    Value<String?>? freezeMonth,
  }) {
    return StreakStateCompanion(
      id: id ?? this.id,
      current: current ?? this.current,
      longest: longest ?? this.longest,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      freezesLeft: freezesLeft ?? this.freezesLeft,
      freezeMonth: freezeMonth ?? this.freezeMonth,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (current.present) {
      map['current'] = Variable<int>(current.value);
    }
    if (longest.present) {
      map['longest'] = Variable<int>(longest.value);
    }
    if (lastActiveDay.present) {
      map['last_active_day'] = Variable<String>(lastActiveDay.value);
    }
    if (freezesLeft.present) {
      map['freezes_left'] = Variable<int>(freezesLeft.value);
    }
    if (freezeMonth.present) {
      map['freeze_month'] = Variable<String>(freezeMonth.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakStateCompanion(')
          ..write('id: $id, ')
          ..write('current: $current, ')
          ..write('longest: $longest, ')
          ..write('lastActiveDay: $lastActiveDay, ')
          ..write('freezesLeft: $freezesLeft, ')
          ..write('freezeMonth: $freezeMonth')
          ..write(')'))
        .toString();
  }
}

class $SafetyFlagsTable extends SafetyFlags
    with TableInfo<$SafetyFlagsTable, SafetyFlag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SafetyFlagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shownAtMeta = const VerificationMeta(
    'shownAt',
  );
  @override
  late final GeneratedColumn<int> shownAt = GeneratedColumn<int>(
    'shown_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<int> dismissedAt = GeneratedColumn<int>(
    'dismissed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localDay,
    kind,
    shownAt,
    dismissedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'safety_flags';
  @override
  VerificationContext validateIntegrity(
    Insertable<SafetyFlag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('shown_at')) {
      context.handle(
        _shownAtMeta,
        shownAt.isAcceptableOrUnknown(data['shown_at']!, _shownAtMeta),
      );
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SafetyFlag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SafetyFlag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      shownAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}shown_at'],
      ),
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissed_at'],
      ),
    );
  }

  @override
  $SafetyFlagsTable createAlias(String alias) {
    return $SafetyFlagsTable(attachedDatabase, alias);
  }
}

class SafetyFlag extends DataClass implements Insertable<SafetyFlag> {
  final String id;
  final String localDay;
  final String kind;
  final int? shownAt;
  final int? dismissedAt;
  const SafetyFlag({
    required this.id,
    required this.localDay,
    required this.kind,
    this.shownAt,
    this.dismissedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['local_day'] = Variable<String>(localDay);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || shownAt != null) {
      map['shown_at'] = Variable<int>(shownAt);
    }
    if (!nullToAbsent || dismissedAt != null) {
      map['dismissed_at'] = Variable<int>(dismissedAt);
    }
    return map;
  }

  SafetyFlagsCompanion toCompanion(bool nullToAbsent) {
    return SafetyFlagsCompanion(
      id: Value(id),
      localDay: Value(localDay),
      kind: Value(kind),
      shownAt: shownAt == null && nullToAbsent
          ? const Value.absent()
          : Value(shownAt),
      dismissedAt: dismissedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAt),
    );
  }

  factory SafetyFlag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SafetyFlag(
      id: serializer.fromJson<String>(json['id']),
      localDay: serializer.fromJson<String>(json['localDay']),
      kind: serializer.fromJson<String>(json['kind']),
      shownAt: serializer.fromJson<int?>(json['shownAt']),
      dismissedAt: serializer.fromJson<int?>(json['dismissedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'localDay': serializer.toJson<String>(localDay),
      'kind': serializer.toJson<String>(kind),
      'shownAt': serializer.toJson<int?>(shownAt),
      'dismissedAt': serializer.toJson<int?>(dismissedAt),
    };
  }

  SafetyFlag copyWith({
    String? id,
    String? localDay,
    String? kind,
    Value<int?> shownAt = const Value.absent(),
    Value<int?> dismissedAt = const Value.absent(),
  }) => SafetyFlag(
    id: id ?? this.id,
    localDay: localDay ?? this.localDay,
    kind: kind ?? this.kind,
    shownAt: shownAt.present ? shownAt.value : this.shownAt,
    dismissedAt: dismissedAt.present ? dismissedAt.value : this.dismissedAt,
  );
  SafetyFlag copyWithCompanion(SafetyFlagsCompanion data) {
    return SafetyFlag(
      id: data.id.present ? data.id.value : this.id,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      kind: data.kind.present ? data.kind.value : this.kind,
      shownAt: data.shownAt.present ? data.shownAt.value : this.shownAt,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SafetyFlag(')
          ..write('id: $id, ')
          ..write('localDay: $localDay, ')
          ..write('kind: $kind, ')
          ..write('shownAt: $shownAt, ')
          ..write('dismissedAt: $dismissedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, localDay, kind, shownAt, dismissedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SafetyFlag &&
          other.id == this.id &&
          other.localDay == this.localDay &&
          other.kind == this.kind &&
          other.shownAt == this.shownAt &&
          other.dismissedAt == this.dismissedAt);
}

class SafetyFlagsCompanion extends UpdateCompanion<SafetyFlag> {
  final Value<String> id;
  final Value<String> localDay;
  final Value<String> kind;
  final Value<int?> shownAt;
  final Value<int?> dismissedAt;
  final Value<int> rowid;
  const SafetyFlagsCompanion({
    this.id = const Value.absent(),
    this.localDay = const Value.absent(),
    this.kind = const Value.absent(),
    this.shownAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SafetyFlagsCompanion.insert({
    required String id,
    required String localDay,
    required String kind,
    this.shownAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localDay = Value(localDay),
       kind = Value(kind);
  static Insertable<SafetyFlag> custom({
    Expression<String>? id,
    Expression<String>? localDay,
    Expression<String>? kind,
    Expression<int>? shownAt,
    Expression<int>? dismissedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localDay != null) 'local_day': localDay,
      if (kind != null) 'kind': kind,
      if (shownAt != null) 'shown_at': shownAt,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SafetyFlagsCompanion copyWith({
    Value<String>? id,
    Value<String>? localDay,
    Value<String>? kind,
    Value<int?>? shownAt,
    Value<int?>? dismissedAt,
    Value<int>? rowid,
  }) {
    return SafetyFlagsCompanion(
      id: id ?? this.id,
      localDay: localDay ?? this.localDay,
      kind: kind ?? this.kind,
      shownAt: shownAt ?? this.shownAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (shownAt.present) {
      map['shown_at'] = Variable<int>(shownAt.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<int>(dismissedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SafetyFlagsCompanion(')
          ..write('id: $id, ')
          ..write('localDay: $localDay, ')
          ..write('kind: $kind, ')
          ..write('shownAt: $shownAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationLogTable extends NotificationLog
    with TableInfo<$NotificationLogTable, NotificationLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledForMeta = const VerificationMeta(
    'scheduledFor',
  );
  @override
  late final GeneratedColumn<int> scheduledFor = GeneratedColumn<int>(
    'scheduled_for',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveredAtMeta = const VerificationMeta(
    'deliveredAt',
  );
  @override
  late final GeneratedColumn<int> deliveredAt = GeneratedColumn<int>(
    'delivered_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<int> openedAt = GeneratedColumn<int>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    scheduledFor,
    deliveredAt,
    openedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('scheduled_for')) {
      context.handle(
        _scheduledForMeta,
        scheduledFor.isAcceptableOrUnknown(
          data['scheduled_for']!,
          _scheduledForMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledForMeta);
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
        _deliveredAtMeta,
        deliveredAt.isAcceptableOrUnknown(
          data['delivered_at']!,
          _deliveredAtMeta,
        ),
      );
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      scheduledFor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_for'],
      )!,
      deliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}delivered_at'],
      ),
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_at'],
      ),
    );
  }

  @override
  $NotificationLogTable createAlias(String alias) {
    return $NotificationLogTable(attachedDatabase, alias);
  }
}

class NotificationLogData extends DataClass
    implements Insertable<NotificationLogData> {
  final String id;
  final String type;
  final int scheduledFor;
  final int? deliveredAt;
  final int? openedAt;
  const NotificationLogData({
    required this.id,
    required this.type,
    required this.scheduledFor,
    this.deliveredAt,
    this.openedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['scheduled_for'] = Variable<int>(scheduledFor);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<int>(deliveredAt);
    }
    if (!nullToAbsent || openedAt != null) {
      map['opened_at'] = Variable<int>(openedAt);
    }
    return map;
  }

  NotificationLogCompanion toCompanion(bool nullToAbsent) {
    return NotificationLogCompanion(
      id: Value(id),
      type: Value(type),
      scheduledFor: Value(scheduledFor),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      openedAt: openedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(openedAt),
    );
  }

  factory NotificationLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationLogData(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      scheduledFor: serializer.fromJson<int>(json['scheduledFor']),
      deliveredAt: serializer.fromJson<int?>(json['deliveredAt']),
      openedAt: serializer.fromJson<int?>(json['openedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'scheduledFor': serializer.toJson<int>(scheduledFor),
      'deliveredAt': serializer.toJson<int?>(deliveredAt),
      'openedAt': serializer.toJson<int?>(openedAt),
    };
  }

  NotificationLogData copyWith({
    String? id,
    String? type,
    int? scheduledFor,
    Value<int?> deliveredAt = const Value.absent(),
    Value<int?> openedAt = const Value.absent(),
  }) => NotificationLogData(
    id: id ?? this.id,
    type: type ?? this.type,
    scheduledFor: scheduledFor ?? this.scheduledFor,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
    openedAt: openedAt.present ? openedAt.value : this.openedAt,
  );
  NotificationLogData copyWithCompanion(NotificationLogCompanion data) {
    return NotificationLogData(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      scheduledFor: data.scheduledFor.present
          ? data.scheduledFor.value
          : this.scheduledFor,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationLogData(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('openedAt: $openedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, type, scheduledFor, deliveredAt, openedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationLogData &&
          other.id == this.id &&
          other.type == this.type &&
          other.scheduledFor == this.scheduledFor &&
          other.deliveredAt == this.deliveredAt &&
          other.openedAt == this.openedAt);
}

class NotificationLogCompanion extends UpdateCompanion<NotificationLogData> {
  final Value<String> id;
  final Value<String> type;
  final Value<int> scheduledFor;
  final Value<int?> deliveredAt;
  final Value<int?> openedAt;
  final Value<int> rowid;
  const NotificationLogCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.scheduledFor = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationLogCompanion.insert({
    required String id,
    required String type,
    required int scheduledFor,
    this.deliveredAt = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       scheduledFor = Value(scheduledFor);
  static Insertable<NotificationLogData> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? scheduledFor,
    Expression<int>? deliveredAt,
    Expression<int>? openedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (scheduledFor != null) 'scheduled_for': scheduledFor,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (openedAt != null) 'opened_at': openedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationLogCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<int>? scheduledFor,
    Value<int?>? deliveredAt,
    Value<int?>? openedAt,
    Value<int>? rowid,
  }) {
    return NotificationLogCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      openedAt: openedAt ?? this.openedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (scheduledFor.present) {
      map['scheduled_for'] = Variable<int>(scheduledFor.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<int>(deliveredAt.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<int>(openedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationLogCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('openedAt: $openedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntitlementCacheTable extends EntitlementCache
    with TableInfo<$EntitlementCacheTable, EntitlementCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntitlementCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateJsonMeta = const VerificationMeta(
    'stateJson',
  );
  @override
  late final GeneratedColumn<String> stateJson = GeneratedColumn<String>(
    'state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kidMeta = const VerificationMeta('kid');
  @override
  late final GeneratedColumn<String> kid = GeneratedColumn<String>(
    'kid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingVerificationUntilMeta =
      const VerificationMeta('pendingVerificationUntil');
  @override
  late final GeneratedColumn<int> pendingVerificationUntil =
      GeneratedColumn<int>(
        'pending_verification_until',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    stateJson,
    signature,
    kid,
    fetchedAt,
    pendingVerificationUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entitlement_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntitlementCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('state_json')) {
      context.handle(
        _stateJsonMeta,
        stateJson.isAcceptableOrUnknown(data['state_json']!, _stateJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stateJsonMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('kid')) {
      context.handle(
        _kidMeta,
        kid.isAcceptableOrUnknown(data['kid']!, _kidMeta),
      );
    } else if (isInserting) {
      context.missing(_kidMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('pending_verification_until')) {
      context.handle(
        _pendingVerificationUntilMeta,
        pendingVerificationUntil.isAcceptableOrUnknown(
          data['pending_verification_until']!,
          _pendingVerificationUntilMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EntitlementCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntitlementCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      stateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_json'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      kid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kid'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
      pendingVerificationUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_verification_until'],
      ),
    );
  }

  @override
  $EntitlementCacheTable createAlias(String alias) {
    return $EntitlementCacheTable(attachedDatabase, alias);
  }
}

class EntitlementCacheData extends DataClass
    implements Insertable<EntitlementCacheData> {
  final int id;
  final String stateJson;
  final String signature;
  final String kid;
  final int fetchedAt;
  final int? pendingVerificationUntil;
  const EntitlementCacheData({
    required this.id,
    required this.stateJson,
    required this.signature,
    required this.kid,
    required this.fetchedAt,
    this.pendingVerificationUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['state_json'] = Variable<String>(stateJson);
    map['signature'] = Variable<String>(signature);
    map['kid'] = Variable<String>(kid);
    map['fetched_at'] = Variable<int>(fetchedAt);
    if (!nullToAbsent || pendingVerificationUntil != null) {
      map['pending_verification_until'] = Variable<int>(
        pendingVerificationUntil,
      );
    }
    return map;
  }

  EntitlementCacheCompanion toCompanion(bool nullToAbsent) {
    return EntitlementCacheCompanion(
      id: Value(id),
      stateJson: Value(stateJson),
      signature: Value(signature),
      kid: Value(kid),
      fetchedAt: Value(fetchedAt),
      pendingVerificationUntil: pendingVerificationUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingVerificationUntil),
    );
  }

  factory EntitlementCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntitlementCacheData(
      id: serializer.fromJson<int>(json['id']),
      stateJson: serializer.fromJson<String>(json['stateJson']),
      signature: serializer.fromJson<String>(json['signature']),
      kid: serializer.fromJson<String>(json['kid']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
      pendingVerificationUntil: serializer.fromJson<int?>(
        json['pendingVerificationUntil'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'stateJson': serializer.toJson<String>(stateJson),
      'signature': serializer.toJson<String>(signature),
      'kid': serializer.toJson<String>(kid),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
      'pendingVerificationUntil': serializer.toJson<int?>(
        pendingVerificationUntil,
      ),
    };
  }

  EntitlementCacheData copyWith({
    int? id,
    String? stateJson,
    String? signature,
    String? kid,
    int? fetchedAt,
    Value<int?> pendingVerificationUntil = const Value.absent(),
  }) => EntitlementCacheData(
    id: id ?? this.id,
    stateJson: stateJson ?? this.stateJson,
    signature: signature ?? this.signature,
    kid: kid ?? this.kid,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    pendingVerificationUntil: pendingVerificationUntil.present
        ? pendingVerificationUntil.value
        : this.pendingVerificationUntil,
  );
  EntitlementCacheData copyWithCompanion(EntitlementCacheCompanion data) {
    return EntitlementCacheData(
      id: data.id.present ? data.id.value : this.id,
      stateJson: data.stateJson.present ? data.stateJson.value : this.stateJson,
      signature: data.signature.present ? data.signature.value : this.signature,
      kid: data.kid.present ? data.kid.value : this.kid,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      pendingVerificationUntil: data.pendingVerificationUntil.present
          ? data.pendingVerificationUntil.value
          : this.pendingVerificationUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntitlementCacheData(')
          ..write('id: $id, ')
          ..write('stateJson: $stateJson, ')
          ..write('signature: $signature, ')
          ..write('kid: $kid, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('pendingVerificationUntil: $pendingVerificationUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    stateJson,
    signature,
    kid,
    fetchedAt,
    pendingVerificationUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntitlementCacheData &&
          other.id == this.id &&
          other.stateJson == this.stateJson &&
          other.signature == this.signature &&
          other.kid == this.kid &&
          other.fetchedAt == this.fetchedAt &&
          other.pendingVerificationUntil == this.pendingVerificationUntil);
}

class EntitlementCacheCompanion extends UpdateCompanion<EntitlementCacheData> {
  final Value<int> id;
  final Value<String> stateJson;
  final Value<String> signature;
  final Value<String> kid;
  final Value<int> fetchedAt;
  final Value<int?> pendingVerificationUntil;
  const EntitlementCacheCompanion({
    this.id = const Value.absent(),
    this.stateJson = const Value.absent(),
    this.signature = const Value.absent(),
    this.kid = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.pendingVerificationUntil = const Value.absent(),
  });
  EntitlementCacheCompanion.insert({
    this.id = const Value.absent(),
    required String stateJson,
    required String signature,
    required String kid,
    required int fetchedAt,
    this.pendingVerificationUntil = const Value.absent(),
  }) : stateJson = Value(stateJson),
       signature = Value(signature),
       kid = Value(kid),
       fetchedAt = Value(fetchedAt);
  static Insertable<EntitlementCacheData> custom({
    Expression<int>? id,
    Expression<String>? stateJson,
    Expression<String>? signature,
    Expression<String>? kid,
    Expression<int>? fetchedAt,
    Expression<int>? pendingVerificationUntil,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stateJson != null) 'state_json': stateJson,
      if (signature != null) 'signature': signature,
      if (kid != null) 'kid': kid,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (pendingVerificationUntil != null)
        'pending_verification_until': pendingVerificationUntil,
    });
  }

  EntitlementCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? stateJson,
    Value<String>? signature,
    Value<String>? kid,
    Value<int>? fetchedAt,
    Value<int?>? pendingVerificationUntil,
  }) {
    return EntitlementCacheCompanion(
      id: id ?? this.id,
      stateJson: stateJson ?? this.stateJson,
      signature: signature ?? this.signature,
      kid: kid ?? this.kid,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      pendingVerificationUntil:
          pendingVerificationUntil ?? this.pendingVerificationUntil,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (stateJson.present) {
      map['state_json'] = Variable<String>(stateJson.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (kid.present) {
      map['kid'] = Variable<String>(kid.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (pendingVerificationUntil.present) {
      map['pending_verification_until'] = Variable<int>(
        pendingVerificationUntil.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntitlementCacheCompanion(')
          ..write('id: $id, ')
          ..write('stateJson: $stateJson, ')
          ..write('signature: $signature, ')
          ..write('kid: $kid, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('pendingVerificationUntil: $pendingVerificationUntil')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAt = GeneratedColumn<int>(
    'next_attempt_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    payload,
    attempts,
    nextAttemptAt,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String id;
  final String kind;
  final String payload;
  final int attempts;
  final int nextAttemptAt;
  final String? lastError;
  final int createdAt;
  const OutboxData({
    required this.id,
    required this.kind,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['payload'] = Variable<String>(payload);
    map['attempts'] = Variable<int>(attempts);
    map['next_attempt_at'] = Variable<int>(nextAttemptAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: Value(payload),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      payload: serializer.fromJson<String>(json['payload']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<int>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'payload': serializer.toJson<String>(payload),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<int>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OutboxData copyWith({
    String? id,
    String? kind,
    String? payload,
    int? attempts,
    int? nextAttemptAt,
    Value<String?> lastError = const Value.absent(),
    int? createdAt,
  }) => OutboxData(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    payload,
    attempts,
    nextAttemptAt,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> payload;
  final Value<int> attempts;
  final Value<int> nextAttemptAt;
  final Value<String?> lastError;
  final Value<int> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required String kind,
    required String payload,
    this.attempts = const Value.absent(),
    required int nextAttemptAt,
    this.lastError = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       payload = Value(payload),
       nextAttemptAt = Value(nextAttemptAt),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<int>? attempts,
    Expression<int>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? payload,
    Value<int>? attempts,
    Value<int>? nextAttemptAt,
    Value<String?>? lastError,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<int>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalyticsQueueTable extends AnalyticsQueue
    with TableInfo<$AnalyticsQueueTable, AnalyticsQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalyticsQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _propsMeta = const VerificationMeta('props');
  @override
  late final GeneratedColumn<String> props = GeneratedColumn<String>(
    'props',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, props, ts, sessionId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analytics_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalyticsQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('props')) {
      context.handle(
        _propsMeta,
        props.isAcceptableOrUnknown(data['props']!, _propsMeta),
      );
    } else if (isInserting) {
      context.missing(_propsMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalyticsQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalyticsQueueData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      props: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}props'],
      )!,
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ts'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
    );
  }

  @override
  $AnalyticsQueueTable createAlias(String alias) {
    return $AnalyticsQueueTable(attachedDatabase, alias);
  }
}

class AnalyticsQueueData extends DataClass
    implements Insertable<AnalyticsQueueData> {
  final String id;
  final String name;
  final String props;
  final int ts;
  final String sessionId;
  const AnalyticsQueueData({
    required this.id,
    required this.name,
    required this.props,
    required this.ts,
    required this.sessionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['props'] = Variable<String>(props);
    map['ts'] = Variable<int>(ts);
    map['session_id'] = Variable<String>(sessionId);
    return map;
  }

  AnalyticsQueueCompanion toCompanion(bool nullToAbsent) {
    return AnalyticsQueueCompanion(
      id: Value(id),
      name: Value(name),
      props: Value(props),
      ts: Value(ts),
      sessionId: Value(sessionId),
    );
  }

  factory AnalyticsQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalyticsQueueData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      props: serializer.fromJson<String>(json['props']),
      ts: serializer.fromJson<int>(json['ts']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'props': serializer.toJson<String>(props),
      'ts': serializer.toJson<int>(ts),
      'sessionId': serializer.toJson<String>(sessionId),
    };
  }

  AnalyticsQueueData copyWith({
    String? id,
    String? name,
    String? props,
    int? ts,
    String? sessionId,
  }) => AnalyticsQueueData(
    id: id ?? this.id,
    name: name ?? this.name,
    props: props ?? this.props,
    ts: ts ?? this.ts,
    sessionId: sessionId ?? this.sessionId,
  );
  AnalyticsQueueData copyWithCompanion(AnalyticsQueueCompanion data) {
    return AnalyticsQueueData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      props: data.props.present ? data.props.value : this.props,
      ts: data.ts.present ? data.ts.value : this.ts,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsQueueData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('props: $props, ')
          ..write('ts: $ts, ')
          ..write('sessionId: $sessionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, props, ts, sessionId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalyticsQueueData &&
          other.id == this.id &&
          other.name == this.name &&
          other.props == this.props &&
          other.ts == this.ts &&
          other.sessionId == this.sessionId);
}

class AnalyticsQueueCompanion extends UpdateCompanion<AnalyticsQueueData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> props;
  final Value<int> ts;
  final Value<String> sessionId;
  final Value<int> rowid;
  const AnalyticsQueueCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.props = const Value.absent(),
    this.ts = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnalyticsQueueCompanion.insert({
    required String id,
    required String name,
    required String props,
    required int ts,
    required String sessionId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       props = Value(props),
       ts = Value(ts),
       sessionId = Value(sessionId);
  static Insertable<AnalyticsQueueData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? props,
    Expression<int>? ts,
    Expression<String>? sessionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (props != null) 'props': props,
      if (ts != null) 'ts': ts,
      if (sessionId != null) 'session_id': sessionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnalyticsQueueCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? props,
    Value<int>? ts,
    Value<String>? sessionId,
    Value<int>? rowid,
  }) {
    return AnalyticsQueueCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      props: props ?? this.props,
      ts: ts ?? this.ts,
      sessionId: sessionId ?? this.sessionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (props.present) {
      map['props'] = Variable<String>(props.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsQueueCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('props: $props, ')
          ..write('ts: $ts, ')
          ..write('sessionId: $sessionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentCacheTable extends ContentCache
    with TableInfo<$ContentCacheTable, ContentCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packKeyMeta = const VerificationMeta(
    'packKey',
  );
  @override
  late final GeneratedColumn<String> packKey = GeneratedColumn<String>(
    'pack_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [packKey, version, sha256, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pack_key')) {
      context.handle(
        _packKeyMeta,
        packKey.isAcceptableOrUnknown(data['pack_key']!, _packKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_packKeyMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packKey};
  @override
  ContentCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentCacheData(
      packKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pack_key'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $ContentCacheTable createAlias(String alias) {
    return $ContentCacheTable(attachedDatabase, alias);
  }
}

class ContentCacheData extends DataClass
    implements Insertable<ContentCacheData> {
  final String packKey;
  final int version;
  final String sha256;
  final String payload;
  const ContentCacheData({
    required this.packKey,
    required this.version,
    required this.sha256,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pack_key'] = Variable<String>(packKey);
    map['version'] = Variable<int>(version);
    map['sha256'] = Variable<String>(sha256);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  ContentCacheCompanion toCompanion(bool nullToAbsent) {
    return ContentCacheCompanion(
      packKey: Value(packKey),
      version: Value(version),
      sha256: Value(sha256),
      payload: Value(payload),
    );
  }

  factory ContentCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentCacheData(
      packKey: serializer.fromJson<String>(json['packKey']),
      version: serializer.fromJson<int>(json['version']),
      sha256: serializer.fromJson<String>(json['sha256']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'packKey': serializer.toJson<String>(packKey),
      'version': serializer.toJson<int>(version),
      'sha256': serializer.toJson<String>(sha256),
      'payload': serializer.toJson<String>(payload),
    };
  }

  ContentCacheData copyWith({
    String? packKey,
    int? version,
    String? sha256,
    String? payload,
  }) => ContentCacheData(
    packKey: packKey ?? this.packKey,
    version: version ?? this.version,
    sha256: sha256 ?? this.sha256,
    payload: payload ?? this.payload,
  );
  ContentCacheData copyWithCompanion(ContentCacheCompanion data) {
    return ContentCacheData(
      packKey: data.packKey.present ? data.packKey.value : this.packKey,
      version: data.version.present ? data.version.value : this.version,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentCacheData(')
          ..write('packKey: $packKey, ')
          ..write('version: $version, ')
          ..write('sha256: $sha256, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(packKey, version, sha256, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentCacheData &&
          other.packKey == this.packKey &&
          other.version == this.version &&
          other.sha256 == this.sha256 &&
          other.payload == this.payload);
}

class ContentCacheCompanion extends UpdateCompanion<ContentCacheData> {
  final Value<String> packKey;
  final Value<int> version;
  final Value<String> sha256;
  final Value<String> payload;
  final Value<int> rowid;
  const ContentCacheCompanion({
    this.packKey = const Value.absent(),
    this.version = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentCacheCompanion.insert({
    required String packKey,
    required int version,
    required String sha256,
    required String payload,
    this.rowid = const Value.absent(),
  }) : packKey = Value(packKey),
       version = Value(version),
       sha256 = Value(sha256),
       payload = Value(payload);
  static Insertable<ContentCacheData> custom({
    Expression<String>? packKey,
    Expression<int>? version,
    Expression<String>? sha256,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packKey != null) 'pack_key': packKey,
      if (version != null) 'version': version,
      if (sha256 != null) 'sha256': sha256,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentCacheCompanion copyWith({
    Value<String>? packKey,
    Value<int>? version,
    Value<String>? sha256,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return ContentCacheCompanion(
      packKey: packKey ?? this.packKey,
      version: version ?? this.version,
      sha256: sha256 ?? this.sha256,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packKey.present) {
      map['pack_key'] = Variable<String>(packKey.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentCacheCompanion(')
          ..write('packKey: $packKey, ')
          ..write('version: $version, ')
          ..write('sha256: $sha256, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SupportMessagesCacheTable extends SupportMessagesCache
    with TableInfo<$SupportMessagesCacheTable, SupportMessagesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SupportMessagesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientMsgIdMeta = const VerificationMeta(
    'clientMsgId',
  );
  @override
  late final GeneratedColumn<String> clientMsgId = GeneratedColumn<String>(
    'client_msg_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<int> readAt = GeneratedColumn<int>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operatorNameMeta = const VerificationMeta(
    'operatorName',
  );
  @override
  late final GeneratedColumn<String> operatorName = GeneratedColumn<String>(
    'operator_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientMsgId,
    sender,
    body,
    createdAt,
    status,
    readAt,
    operatorName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'support_messages_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<SupportMessagesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_msg_id')) {
      context.handle(
        _clientMsgIdMeta,
        clientMsgId.isAcceptableOrUnknown(
          data['client_msg_id']!,
          _clientMsgIdMeta,
        ),
      );
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('operator_name')) {
      context.handle(
        _operatorNameMeta,
        operatorName.isAcceptableOrUnknown(
          data['operator_name']!,
          _operatorNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SupportMessagesCacheData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SupportMessagesCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientMsgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_msg_id'],
      ),
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}read_at'],
      ),
      operatorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operator_name'],
      ),
    );
  }

  @override
  $SupportMessagesCacheTable createAlias(String alias) {
    return $SupportMessagesCacheTable(attachedDatabase, alias);
  }
}

class SupportMessagesCacheData extends DataClass
    implements Insertable<SupportMessagesCacheData> {
  final String id;
  final String? clientMsgId;
  final String sender;
  final String body;
  final int createdAt;
  final String status;
  final int? readAt;
  final String? operatorName;
  const SupportMessagesCacheData({
    required this.id,
    this.clientMsgId,
    required this.sender,
    required this.body,
    required this.createdAt,
    required this.status,
    this.readAt,
    this.operatorName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || clientMsgId != null) {
      map['client_msg_id'] = Variable<String>(clientMsgId);
    }
    map['sender'] = Variable<String>(sender);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<int>(createdAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<int>(readAt);
    }
    if (!nullToAbsent || operatorName != null) {
      map['operator_name'] = Variable<String>(operatorName);
    }
    return map;
  }

  SupportMessagesCacheCompanion toCompanion(bool nullToAbsent) {
    return SupportMessagesCacheCompanion(
      id: Value(id),
      clientMsgId: clientMsgId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientMsgId),
      sender: Value(sender),
      body: Value(body),
      createdAt: Value(createdAt),
      status: Value(status),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      operatorName: operatorName == null && nullToAbsent
          ? const Value.absent()
          : Value(operatorName),
    );
  }

  factory SupportMessagesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SupportMessagesCacheData(
      id: serializer.fromJson<String>(json['id']),
      clientMsgId: serializer.fromJson<String?>(json['clientMsgId']),
      sender: serializer.fromJson<String>(json['sender']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      readAt: serializer.fromJson<int?>(json['readAt']),
      operatorName: serializer.fromJson<String?>(json['operatorName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientMsgId': serializer.toJson<String?>(clientMsgId),
      'sender': serializer.toJson<String>(sender),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<int>(createdAt),
      'status': serializer.toJson<String>(status),
      'readAt': serializer.toJson<int?>(readAt),
      'operatorName': serializer.toJson<String?>(operatorName),
    };
  }

  SupportMessagesCacheData copyWith({
    String? id,
    Value<String?> clientMsgId = const Value.absent(),
    String? sender,
    String? body,
    int? createdAt,
    String? status,
    Value<int?> readAt = const Value.absent(),
    Value<String?> operatorName = const Value.absent(),
  }) => SupportMessagesCacheData(
    id: id ?? this.id,
    clientMsgId: clientMsgId.present ? clientMsgId.value : this.clientMsgId,
    sender: sender ?? this.sender,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    readAt: readAt.present ? readAt.value : this.readAt,
    operatorName: operatorName.present ? operatorName.value : this.operatorName,
  );
  SupportMessagesCacheData copyWithCompanion(
    SupportMessagesCacheCompanion data,
  ) {
    return SupportMessagesCacheData(
      id: data.id.present ? data.id.value : this.id,
      clientMsgId: data.clientMsgId.present
          ? data.clientMsgId.value
          : this.clientMsgId,
      sender: data.sender.present ? data.sender.value : this.sender,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      operatorName: data.operatorName.present
          ? data.operatorName.value
          : this.operatorName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SupportMessagesCacheData(')
          ..write('id: $id, ')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('readAt: $readAt, ')
          ..write('operatorName: $operatorName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientMsgId,
    sender,
    body,
    createdAt,
    status,
    readAt,
    operatorName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SupportMessagesCacheData &&
          other.id == this.id &&
          other.clientMsgId == this.clientMsgId &&
          other.sender == this.sender &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.readAt == this.readAt &&
          other.operatorName == this.operatorName);
}

class SupportMessagesCacheCompanion
    extends UpdateCompanion<SupportMessagesCacheData> {
  final Value<String> id;
  final Value<String?> clientMsgId;
  final Value<String> sender;
  final Value<String> body;
  final Value<int> createdAt;
  final Value<String> status;
  final Value<int?> readAt;
  final Value<String?> operatorName;
  final Value<int> rowid;
  const SupportMessagesCacheCompanion({
    this.id = const Value.absent(),
    this.clientMsgId = const Value.absent(),
    this.sender = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.readAt = const Value.absent(),
    this.operatorName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SupportMessagesCacheCompanion.insert({
    required String id,
    this.clientMsgId = const Value.absent(),
    required String sender,
    required String body,
    required int createdAt,
    required String status,
    this.readAt = const Value.absent(),
    this.operatorName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sender = Value(sender),
       body = Value(body),
       createdAt = Value(createdAt),
       status = Value(status);
  static Insertable<SupportMessagesCacheData> custom({
    Expression<String>? id,
    Expression<String>? clientMsgId,
    Expression<String>? sender,
    Expression<String>? body,
    Expression<int>? createdAt,
    Expression<String>? status,
    Expression<int>? readAt,
    Expression<String>? operatorName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientMsgId != null) 'client_msg_id': clientMsgId,
      if (sender != null) 'sender': sender,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (readAt != null) 'read_at': readAt,
      if (operatorName != null) 'operator_name': operatorName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SupportMessagesCacheCompanion copyWith({
    Value<String>? id,
    Value<String?>? clientMsgId,
    Value<String>? sender,
    Value<String>? body,
    Value<int>? createdAt,
    Value<String>? status,
    Value<int?>? readAt,
    Value<String?>? operatorName,
    Value<int>? rowid,
  }) {
    return SupportMessagesCacheCompanion(
      id: id ?? this.id,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      readAt: readAt ?? this.readAt,
      operatorName: operatorName ?? this.operatorName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientMsgId.present) {
      map['client_msg_id'] = Variable<String>(clientMsgId.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<int>(readAt.value);
    }
    if (operatorName.present) {
      map['operator_name'] = Variable<String>(operatorName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SupportMessagesCacheCompanion(')
          ..write('id: $id, ')
          ..write('clientMsgId: $clientMsgId, ')
          ..write('sender: $sender, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('readAt: $readAt, ')
          ..write('operatorName: $operatorName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnboardingAnswersTable extends OnboardingAnswers
    with TableInfo<$OnboardingAnswersTable, OnboardingAnswer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnboardingAnswersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_answers';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnboardingAnswer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  OnboardingAnswer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingAnswer(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $OnboardingAnswersTable createAlias(String alias) {
    return $OnboardingAnswersTable(attachedDatabase, alias);
  }
}

class OnboardingAnswer extends DataClass
    implements Insertable<OnboardingAnswer> {
  final String key;
  final String value;
  const OnboardingAnswer({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  OnboardingAnswersCompanion toCompanion(bool nullToAbsent) {
    return OnboardingAnswersCompanion(key: Value(key), value: Value(value));
  }

  factory OnboardingAnswer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingAnswer(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  OnboardingAnswer copyWith({String? key, String? value}) =>
      OnboardingAnswer(key: key ?? this.key, value: value ?? this.value);
  OnboardingAnswer copyWithCompanion(OnboardingAnswersCompanion data) {
    return OnboardingAnswer(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingAnswer(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingAnswer &&
          other.key == this.key &&
          other.value == this.value);
}

class OnboardingAnswersCompanion extends UpdateCompanion<OnboardingAnswer> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const OnboardingAnswersCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnboardingAnswersCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<OnboardingAnswer> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnboardingAnswersCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return OnboardingAnswersCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingAnswersCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiscoveriesFoundTable extends DiscoveriesFound
    with TableInfo<$DiscoveriesFoundTable, DiscoveriesFoundData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveriesFoundTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _discoveryKeyMeta = const VerificationMeta(
    'discoveryKey',
  );
  @override
  late final GeneratedColumn<String> discoveryKey = GeneratedColumn<String>(
    'discovery_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foundAtMeta = const VerificationMeta(
    'foundAt',
  );
  @override
  late final GeneratedColumn<int> foundAt = GeneratedColumn<int>(
    'found_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [discoveryKey, foundAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discoveries_found';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveriesFoundData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('discovery_key')) {
      context.handle(
        _discoveryKeyMeta,
        discoveryKey.isAcceptableOrUnknown(
          data['discovery_key']!,
          _discoveryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discoveryKeyMeta);
    }
    if (data.containsKey('found_at')) {
      context.handle(
        _foundAtMeta,
        foundAt.isAcceptableOrUnknown(data['found_at']!, _foundAtMeta),
      );
    } else if (isInserting) {
      context.missing(_foundAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {discoveryKey};
  @override
  DiscoveriesFoundData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveriesFoundData(
      discoveryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}discovery_key'],
      )!,
      foundAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}found_at'],
      )!,
    );
  }

  @override
  $DiscoveriesFoundTable createAlias(String alias) {
    return $DiscoveriesFoundTable(attachedDatabase, alias);
  }
}

class DiscoveriesFoundData extends DataClass
    implements Insertable<DiscoveriesFoundData> {
  final String discoveryKey;
  final int foundAt;
  const DiscoveriesFoundData({
    required this.discoveryKey,
    required this.foundAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['discovery_key'] = Variable<String>(discoveryKey);
    map['found_at'] = Variable<int>(foundAt);
    return map;
  }

  DiscoveriesFoundCompanion toCompanion(bool nullToAbsent) {
    return DiscoveriesFoundCompanion(
      discoveryKey: Value(discoveryKey),
      foundAt: Value(foundAt),
    );
  }

  factory DiscoveriesFoundData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveriesFoundData(
      discoveryKey: serializer.fromJson<String>(json['discoveryKey']),
      foundAt: serializer.fromJson<int>(json['foundAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'discoveryKey': serializer.toJson<String>(discoveryKey),
      'foundAt': serializer.toJson<int>(foundAt),
    };
  }

  DiscoveriesFoundData copyWith({String? discoveryKey, int? foundAt}) =>
      DiscoveriesFoundData(
        discoveryKey: discoveryKey ?? this.discoveryKey,
        foundAt: foundAt ?? this.foundAt,
      );
  DiscoveriesFoundData copyWithCompanion(DiscoveriesFoundCompanion data) {
    return DiscoveriesFoundData(
      discoveryKey: data.discoveryKey.present
          ? data.discoveryKey.value
          : this.discoveryKey,
      foundAt: data.foundAt.present ? data.foundAt.value : this.foundAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveriesFoundData(')
          ..write('discoveryKey: $discoveryKey, ')
          ..write('foundAt: $foundAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(discoveryKey, foundAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveriesFoundData &&
          other.discoveryKey == this.discoveryKey &&
          other.foundAt == this.foundAt);
}

class DiscoveriesFoundCompanion extends UpdateCompanion<DiscoveriesFoundData> {
  final Value<String> discoveryKey;
  final Value<int> foundAt;
  final Value<int> rowid;
  const DiscoveriesFoundCompanion({
    this.discoveryKey = const Value.absent(),
    this.foundAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiscoveriesFoundCompanion.insert({
    required String discoveryKey,
    required int foundAt,
    this.rowid = const Value.absent(),
  }) : discoveryKey = Value(discoveryKey),
       foundAt = Value(foundAt);
  static Insertable<DiscoveriesFoundData> custom({
    Expression<String>? discoveryKey,
    Expression<int>? foundAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (discoveryKey != null) 'discovery_key': discoveryKey,
      if (foundAt != null) 'found_at': foundAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiscoveriesFoundCompanion copyWith({
    Value<String>? discoveryKey,
    Value<int>? foundAt,
    Value<int>? rowid,
  }) {
    return DiscoveriesFoundCompanion(
      discoveryKey: discoveryKey ?? this.discoveryKey,
      foundAt: foundAt ?? this.foundAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (discoveryKey.present) {
      map['discovery_key'] = Variable<String>(discoveryKey.value);
    }
    if (foundAt.present) {
      map['found_at'] = Variable<int>(foundAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveriesFoundCompanion(')
          ..write('discoveryKey: $discoveryKey, ')
          ..write('foundAt: $foundAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuestProgressTable extends QuestProgress
    with TableInfo<$QuestProgressTable, QuestProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questKeyMeta = const VerificationMeta(
    'questKey',
  );
  @override
  late final GeneratedColumn<String> questKey = GeneratedColumn<String>(
    'quest_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta(
    'claimedAt',
  );
  @override
  late final GeneratedColumn<int> claimedAt = GeneratedColumn<int>(
    'claimed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [questKey, claimedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quest_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('quest_key')) {
      context.handle(
        _questKeyMeta,
        questKey.isAcceptableOrUnknown(data['quest_key']!, _questKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_questKeyMeta);
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questKey};
  @override
  QuestProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestProgressData(
      questKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quest_key'],
      )!,
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}claimed_at'],
      ),
    );
  }

  @override
  $QuestProgressTable createAlias(String alias) {
    return $QuestProgressTable(attachedDatabase, alias);
  }
}

class QuestProgressData extends DataClass
    implements Insertable<QuestProgressData> {
  final String questKey;
  final int? claimedAt;
  const QuestProgressData({required this.questKey, this.claimedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['quest_key'] = Variable<String>(questKey);
    if (!nullToAbsent || claimedAt != null) {
      map['claimed_at'] = Variable<int>(claimedAt);
    }
    return map;
  }

  QuestProgressCompanion toCompanion(bool nullToAbsent) {
    return QuestProgressCompanion(
      questKey: Value(questKey),
      claimedAt: claimedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(claimedAt),
    );
  }

  factory QuestProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestProgressData(
      questKey: serializer.fromJson<String>(json['questKey']),
      claimedAt: serializer.fromJson<int?>(json['claimedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questKey': serializer.toJson<String>(questKey),
      'claimedAt': serializer.toJson<int?>(claimedAt),
    };
  }

  QuestProgressData copyWith({
    String? questKey,
    Value<int?> claimedAt = const Value.absent(),
  }) => QuestProgressData(
    questKey: questKey ?? this.questKey,
    claimedAt: claimedAt.present ? claimedAt.value : this.claimedAt,
  );
  QuestProgressData copyWithCompanion(QuestProgressCompanion data) {
    return QuestProgressData(
      questKey: data.questKey.present ? data.questKey.value : this.questKey,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestProgressData(')
          ..write('questKey: $questKey, ')
          ..write('claimedAt: $claimedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questKey, claimedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestProgressData &&
          other.questKey == this.questKey &&
          other.claimedAt == this.claimedAt);
}

class QuestProgressCompanion extends UpdateCompanion<QuestProgressData> {
  final Value<String> questKey;
  final Value<int?> claimedAt;
  final Value<int> rowid;
  const QuestProgressCompanion({
    this.questKey = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestProgressCompanion.insert({
    required String questKey,
    this.claimedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : questKey = Value(questKey);
  static Insertable<QuestProgressData> custom({
    Expression<String>? questKey,
    Expression<int>? claimedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questKey != null) 'quest_key': questKey,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestProgressCompanion copyWith({
    Value<String>? questKey,
    Value<int?>? claimedAt,
    Value<int>? rowid,
  }) {
    return QuestProgressCompanion(
      questKey: questKey ?? this.questKey,
      claimedAt: claimedAt ?? this.claimedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questKey.present) {
      map['quest_key'] = Variable<String>(questKey.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<int>(claimedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestProgressCompanion(')
          ..write('questKey: $questKey, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuestDailyStateTable extends QuestDailyState
    with TableInfo<$QuestDailyStateTable, QuestDailyStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuestDailyStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questKeysMeta = const VerificationMeta(
    'questKeys',
  );
  @override
  late final GeneratedColumn<String> questKeys = GeneratedColumn<String>(
    'quest_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimedMeta = const VerificationMeta(
    'claimed',
  );
  @override
  late final GeneratedColumn<String> claimed = GeneratedColumn<String>(
    'claimed',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _reflectionAnswerMeta = const VerificationMeta(
    'reflectionAnswer',
  );
  @override
  late final GeneratedColumn<String> reflectionAnswer = GeneratedColumn<String>(
    'reflection_answer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localDay,
    questKeys,
    claimed,
    reflectionAnswer,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quest_daily_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuestDailyStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('quest_keys')) {
      context.handle(
        _questKeysMeta,
        questKeys.isAcceptableOrUnknown(data['quest_keys']!, _questKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_questKeysMeta);
    }
    if (data.containsKey('claimed')) {
      context.handle(
        _claimedMeta,
        claimed.isAcceptableOrUnknown(data['claimed']!, _claimedMeta),
      );
    }
    if (data.containsKey('reflection_answer')) {
      context.handle(
        _reflectionAnswerMeta,
        reflectionAnswer.isAcceptableOrUnknown(
          data['reflection_answer']!,
          _reflectionAnswerMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localDay};
  @override
  QuestDailyStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuestDailyStateData(
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      questKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quest_keys'],
      )!,
      claimed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claimed'],
      )!,
      reflectionAnswer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reflection_answer'],
      ),
    );
  }

  @override
  $QuestDailyStateTable createAlias(String alias) {
    return $QuestDailyStateTable(attachedDatabase, alias);
  }
}

class QuestDailyStateData extends DataClass
    implements Insertable<QuestDailyStateData> {
  final String localDay;
  final String questKeys;
  final String claimed;
  final String? reflectionAnswer;
  const QuestDailyStateData({
    required this.localDay,
    required this.questKeys,
    required this.claimed,
    this.reflectionAnswer,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_day'] = Variable<String>(localDay);
    map['quest_keys'] = Variable<String>(questKeys);
    map['claimed'] = Variable<String>(claimed);
    if (!nullToAbsent || reflectionAnswer != null) {
      map['reflection_answer'] = Variable<String>(reflectionAnswer);
    }
    return map;
  }

  QuestDailyStateCompanion toCompanion(bool nullToAbsent) {
    return QuestDailyStateCompanion(
      localDay: Value(localDay),
      questKeys: Value(questKeys),
      claimed: Value(claimed),
      reflectionAnswer: reflectionAnswer == null && nullToAbsent
          ? const Value.absent()
          : Value(reflectionAnswer),
    );
  }

  factory QuestDailyStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuestDailyStateData(
      localDay: serializer.fromJson<String>(json['localDay']),
      questKeys: serializer.fromJson<String>(json['questKeys']),
      claimed: serializer.fromJson<String>(json['claimed']),
      reflectionAnswer: serializer.fromJson<String?>(json['reflectionAnswer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localDay': serializer.toJson<String>(localDay),
      'questKeys': serializer.toJson<String>(questKeys),
      'claimed': serializer.toJson<String>(claimed),
      'reflectionAnswer': serializer.toJson<String?>(reflectionAnswer),
    };
  }

  QuestDailyStateData copyWith({
    String? localDay,
    String? questKeys,
    String? claimed,
    Value<String?> reflectionAnswer = const Value.absent(),
  }) => QuestDailyStateData(
    localDay: localDay ?? this.localDay,
    questKeys: questKeys ?? this.questKeys,
    claimed: claimed ?? this.claimed,
    reflectionAnswer: reflectionAnswer.present
        ? reflectionAnswer.value
        : this.reflectionAnswer,
  );
  QuestDailyStateData copyWithCompanion(QuestDailyStateCompanion data) {
    return QuestDailyStateData(
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      questKeys: data.questKeys.present ? data.questKeys.value : this.questKeys,
      claimed: data.claimed.present ? data.claimed.value : this.claimed,
      reflectionAnswer: data.reflectionAnswer.present
          ? data.reflectionAnswer.value
          : this.reflectionAnswer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuestDailyStateData(')
          ..write('localDay: $localDay, ')
          ..write('questKeys: $questKeys, ')
          ..write('claimed: $claimed, ')
          ..write('reflectionAnswer: $reflectionAnswer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(localDay, questKeys, claimed, reflectionAnswer);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestDailyStateData &&
          other.localDay == this.localDay &&
          other.questKeys == this.questKeys &&
          other.claimed == this.claimed &&
          other.reflectionAnswer == this.reflectionAnswer);
}

class QuestDailyStateCompanion extends UpdateCompanion<QuestDailyStateData> {
  final Value<String> localDay;
  final Value<String> questKeys;
  final Value<String> claimed;
  final Value<String?> reflectionAnswer;
  final Value<int> rowid;
  const QuestDailyStateCompanion({
    this.localDay = const Value.absent(),
    this.questKeys = const Value.absent(),
    this.claimed = const Value.absent(),
    this.reflectionAnswer = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuestDailyStateCompanion.insert({
    required String localDay,
    required String questKeys,
    this.claimed = const Value.absent(),
    this.reflectionAnswer = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localDay = Value(localDay),
       questKeys = Value(questKeys);
  static Insertable<QuestDailyStateData> custom({
    Expression<String>? localDay,
    Expression<String>? questKeys,
    Expression<String>? claimed,
    Expression<String>? reflectionAnswer,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localDay != null) 'local_day': localDay,
      if (questKeys != null) 'quest_keys': questKeys,
      if (claimed != null) 'claimed': claimed,
      if (reflectionAnswer != null) 'reflection_answer': reflectionAnswer,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuestDailyStateCompanion copyWith({
    Value<String>? localDay,
    Value<String>? questKeys,
    Value<String>? claimed,
    Value<String?>? reflectionAnswer,
    Value<int>? rowid,
  }) {
    return QuestDailyStateCompanion(
      localDay: localDay ?? this.localDay,
      questKeys: questKeys ?? this.questKeys,
      claimed: claimed ?? this.claimed,
      reflectionAnswer: reflectionAnswer ?? this.reflectionAnswer,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (questKeys.present) {
      map['quest_keys'] = Variable<String>(questKeys.value);
    }
    if (claimed.present) {
      map['claimed'] = Variable<String>(claimed.value);
    }
    if (reflectionAnswer.present) {
      map['reflection_answer'] = Variable<String>(reflectionAnswer.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuestDailyStateCompanion(')
          ..write('localDay: $localDay, ')
          ..write('questKeys: $questKeys, ')
          ..write('claimed: $claimed, ')
          ..write('reflectionAnswer: $reflectionAnswer, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShopRotationTable extends ShopRotation
    with TableInfo<$ShopRotationTable, ShopRotationData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShopRotationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shopMeta = const VerificationMeta('shop');
  @override
  late final GeneratedColumn<String> shop = GeneratedColumn<String>(
    'shop',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refreshCountMeta = const VerificationMeta(
    'refreshCount',
  );
  @override
  late final GeneratedColumn<int> refreshCount = GeneratedColumn<int>(
    'refresh_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _itemKeysMeta = const VerificationMeta(
    'itemKeys',
  );
  @override
  late final GeneratedColumn<String> itemKeys = GeneratedColumn<String>(
    'item_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localDay,
    shop,
    refreshCount,
    itemKeys,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shop_rotation';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShopRotationData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('shop')) {
      context.handle(
        _shopMeta,
        shop.isAcceptableOrUnknown(data['shop']!, _shopMeta),
      );
    } else if (isInserting) {
      context.missing(_shopMeta);
    }
    if (data.containsKey('refresh_count')) {
      context.handle(
        _refreshCountMeta,
        refreshCount.isAcceptableOrUnknown(
          data['refresh_count']!,
          _refreshCountMeta,
        ),
      );
    }
    if (data.containsKey('item_keys')) {
      context.handle(
        _itemKeysMeta,
        itemKeys.isAcceptableOrUnknown(data['item_keys']!, _itemKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeysMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localDay, shop};
  @override
  ShopRotationData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShopRotationData(
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      shop: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shop'],
      )!,
      refreshCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refresh_count'],
      )!,
      itemKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_keys'],
      )!,
    );
  }

  @override
  $ShopRotationTable createAlias(String alias) {
    return $ShopRotationTable(attachedDatabase, alias);
  }
}

class ShopRotationData extends DataClass
    implements Insertable<ShopRotationData> {
  final String localDay;
  final String shop;
  final int refreshCount;
  final String itemKeys;
  const ShopRotationData({
    required this.localDay,
    required this.shop,
    required this.refreshCount,
    required this.itemKeys,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_day'] = Variable<String>(localDay);
    map['shop'] = Variable<String>(shop);
    map['refresh_count'] = Variable<int>(refreshCount);
    map['item_keys'] = Variable<String>(itemKeys);
    return map;
  }

  ShopRotationCompanion toCompanion(bool nullToAbsent) {
    return ShopRotationCompanion(
      localDay: Value(localDay),
      shop: Value(shop),
      refreshCount: Value(refreshCount),
      itemKeys: Value(itemKeys),
    );
  }

  factory ShopRotationData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShopRotationData(
      localDay: serializer.fromJson<String>(json['localDay']),
      shop: serializer.fromJson<String>(json['shop']),
      refreshCount: serializer.fromJson<int>(json['refreshCount']),
      itemKeys: serializer.fromJson<String>(json['itemKeys']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localDay': serializer.toJson<String>(localDay),
      'shop': serializer.toJson<String>(shop),
      'refreshCount': serializer.toJson<int>(refreshCount),
      'itemKeys': serializer.toJson<String>(itemKeys),
    };
  }

  ShopRotationData copyWith({
    String? localDay,
    String? shop,
    int? refreshCount,
    String? itemKeys,
  }) => ShopRotationData(
    localDay: localDay ?? this.localDay,
    shop: shop ?? this.shop,
    refreshCount: refreshCount ?? this.refreshCount,
    itemKeys: itemKeys ?? this.itemKeys,
  );
  ShopRotationData copyWithCompanion(ShopRotationCompanion data) {
    return ShopRotationData(
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      shop: data.shop.present ? data.shop.value : this.shop,
      refreshCount: data.refreshCount.present
          ? data.refreshCount.value
          : this.refreshCount,
      itemKeys: data.itemKeys.present ? data.itemKeys.value : this.itemKeys,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShopRotationData(')
          ..write('localDay: $localDay, ')
          ..write('shop: $shop, ')
          ..write('refreshCount: $refreshCount, ')
          ..write('itemKeys: $itemKeys')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localDay, shop, refreshCount, itemKeys);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShopRotationData &&
          other.localDay == this.localDay &&
          other.shop == this.shop &&
          other.refreshCount == this.refreshCount &&
          other.itemKeys == this.itemKeys);
}

class ShopRotationCompanion extends UpdateCompanion<ShopRotationData> {
  final Value<String> localDay;
  final Value<String> shop;
  final Value<int> refreshCount;
  final Value<String> itemKeys;
  final Value<int> rowid;
  const ShopRotationCompanion({
    this.localDay = const Value.absent(),
    this.shop = const Value.absent(),
    this.refreshCount = const Value.absent(),
    this.itemKeys = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShopRotationCompanion.insert({
    required String localDay,
    required String shop,
    this.refreshCount = const Value.absent(),
    required String itemKeys,
    this.rowid = const Value.absent(),
  }) : localDay = Value(localDay),
       shop = Value(shop),
       itemKeys = Value(itemKeys);
  static Insertable<ShopRotationData> custom({
    Expression<String>? localDay,
    Expression<String>? shop,
    Expression<int>? refreshCount,
    Expression<String>? itemKeys,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localDay != null) 'local_day': localDay,
      if (shop != null) 'shop': shop,
      if (refreshCount != null) 'refresh_count': refreshCount,
      if (itemKeys != null) 'item_keys': itemKeys,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShopRotationCompanion copyWith({
    Value<String>? localDay,
    Value<String>? shop,
    Value<int>? refreshCount,
    Value<String>? itemKeys,
    Value<int>? rowid,
  }) {
    return ShopRotationCompanion(
      localDay: localDay ?? this.localDay,
      shop: shop ?? this.shop,
      refreshCount: refreshCount ?? this.refreshCount,
      itemKeys: itemKeys ?? this.itemKeys,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (shop.present) {
      map['shop'] = Variable<String>(shop.value);
    }
    if (refreshCount.present) {
      map['refresh_count'] = Variable<int>(refreshCount.value);
    }
    if (itemKeys.present) {
      map['item_keys'] = Variable<String>(itemKeys.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShopRotationCompanion(')
          ..write('localDay: $localDay, ')
          ..write('shop: $shop, ')
          ..write('refreshCount: $refreshCount, ')
          ..write('itemKeys: $itemKeys, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $HabitsTable habits = $HabitsTable(this);
  late final $HabitLogsTable habitLogs = $HabitLogsTable(this);
  late final $CheckinsTable checkins = $CheckinsTable(this);
  late final $ExerciseSessionsTable exerciseSessions = $ExerciseSessionsTable(
    this,
  );
  late final $WalletTable wallet = $WalletTable(this);
  late final $WalletLedgerTable walletLedger = $WalletLedgerTable(this);
  late final $AdventuresTable adventures = $AdventuresTable(this);
  late final $InventoryTable inventory = $InventoryTable(this);
  late final $StreakStateTable streakState = $StreakStateTable(this);
  late final $SafetyFlagsTable safetyFlags = $SafetyFlagsTable(this);
  late final $NotificationLogTable notificationLog = $NotificationLogTable(
    this,
  );
  late final $EntitlementCacheTable entitlementCache = $EntitlementCacheTable(
    this,
  );
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $AnalyticsQueueTable analyticsQueue = $AnalyticsQueueTable(this);
  late final $ContentCacheTable contentCache = $ContentCacheTable(this);
  late final $SupportMessagesCacheTable supportMessagesCache =
      $SupportMessagesCacheTable(this);
  late final $OnboardingAnswersTable onboardingAnswers =
      $OnboardingAnswersTable(this);
  late final $DiscoveriesFoundTable discoveriesFound = $DiscoveriesFoundTable(
    this,
  );
  late final $QuestProgressTable questProgress = $QuestProgressTable(this);
  late final $QuestDailyStateTable questDailyState = $QuestDailyStateTable(
    this,
  );
  late final $ShopRotationTable shopRotation = $ShopRotationTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appMeta,
    userSettings,
    habits,
    habitLogs,
    checkins,
    exerciseSessions,
    wallet,
    walletLedger,
    adventures,
    inventory,
    streakState,
    safetyFlags,
    notificationLog,
    entitlementCache,
    outbox,
    analyticsQueue,
    contentCache,
    supportMessagesCache,
    onboardingAnswers,
    discoveriesFound,
    questProgress,
    questDailyState,
    shopRotation,
  ];
}

typedef $$AppMetaTableCreateCompanionBuilder = AppMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetaTableUpdateCompanionBuilder = AppMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
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
}

class $$AppMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppMetaTable,
          AppMetaData,
          $$AppMetaTableFilterComposer,
          $$AppMetaTableOrderingComposer,
          $$AppMetaTableAnnotationComposer,
          $$AppMetaTableCreateCompanionBuilder,
          $$AppMetaTableUpdateCompanionBuilder,
          (
            AppMetaData,
            BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>,
          ),
          AppMetaData,
          PrefetchHooks Function()
        > {
  $$AppMetaTableTableManager(_$AppDatabase db, $AppMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => AppMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppMetaTable, AppMetaData>(table),
                  BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppMetaTable,
      AppMetaData,
      $$AppMetaTableFilterComposer,
      $$AppMetaTableOrderingComposer,
      $$AppMetaTableAnnotationComposer,
      $$AppMetaTableCreateCompanionBuilder,
      $$AppMetaTableUpdateCompanionBuilder,
      (AppMetaData, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>),
      AppMetaData,
      PrefetchHooks Function()
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
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
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSetting,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSetting,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
          ),
          UserSetting,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => UserSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserSettingsTable, UserSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserSettingsTable,
                    UserSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSetting,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSetting,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
      ),
      UserSetting,
      PrefetchHooks Function()
    >;
typedef $$HabitsTableCreateCompanionBuilder = HabitsCompanion Function({
  required String id,
  Value<String?> templateKey,
  Value<String?> goalKey,
  Value<String?> areaKey,
  Value<String> timeOfDay,
  Value<String> repeatType,
  Value<String?> dueDay,
  Value<String?> title,
  Value<String> icon,
  Value<String> scheduleType,
  Value<int> weekdaysMask,
  Value<int> targetPerDay,
  Value<int?> reminderMinutes,
  Value<bool> isCustom,
  Value<bool> isLocked,
  Value<int?> archivedAt,
  Value<int> sortOrder,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$HabitsTableUpdateCompanionBuilder = HabitsCompanion Function({
  Value<String> id,
  Value<String?> templateKey,
  Value<String?> goalKey,
  Value<String?> areaKey,
  Value<String> timeOfDay,
  Value<String> repeatType,
  Value<String?> dueDay,
  Value<String?> title,
  Value<String> icon,
  Value<String> scheduleType,
  Value<int> weekdaysMask,
  Value<int> targetPerDay,
  Value<int?> reminderMinutes,
  Value<bool> isCustom,
  Value<bool> isLocked,
  Value<int?> archivedAt,
  Value<int> sortOrder,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $$HabitsTableReferences
    extends BaseReferences<_$AppDatabase, $HabitsTable, Habit> {
  $$HabitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$HabitLogsTable, List<HabitLog>>
  _habitLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.habitLogs,
    aliasName: 'habits__id__habit_logs__habit_id',
  );

  $$HabitLogsTableProcessedTableManager get habitLogsRefs {
    final manager = $$HabitLogsTableTableManager(
      $_db,
      $_db.habitLogs,
    ).filter((f) => f.habitId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_habitLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalKey => $composableBuilder(
    column: $table.goalKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get areaKey => $composableBuilder(
    column: $table.areaKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetPerDay => $composableBuilder(
    column: $table.targetPerDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> habitLogsRefs(
    Expression<bool> Function($$HabitLogsTableFilterComposer f) f,
  ) {
    final $$HabitLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.habitLogs,
      getReferencedColumn: (t) => t.habitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitLogsTableFilterComposer(
            $db: $db,
            $table: $db.habitLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalKey => $composableBuilder(
    column: $table.goalKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get areaKey => $composableBuilder(
    column: $table.areaKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetPerDay => $composableBuilder(
    column: $table.targetPerDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLocked => $composableBuilder(
    column: $table.isLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get templateKey => $composableBuilder(
    column: $table.templateKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goalKey =>
      $composableBuilder(column: $table.goalKey, builder: (column) => column);

  GeneratedColumn<String> get areaKey =>
      $composableBuilder(column: $table.areaKey, builder: (column) => column);

  GeneratedColumn<String> get timeOfDay =>
      $composableBuilder(column: $table.timeOfDay, builder: (column) => column);

  GeneratedColumn<String> get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get scheduleType => $composableBuilder(
    column: $table.scheduleType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekdaysMask => $composableBuilder(
    column: $table.weekdaysMask,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetPerDay => $composableBuilder(
    column: $table.targetPerDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutes => $composableBuilder(
    column: $table.reminderMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> habitLogsRefs<T extends Object>(
    Expression<T> Function($$HabitLogsTableAnnotationComposer a) f,
  ) {
    final $$HabitLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.habitLogs,
      getReferencedColumn: (t) => t.habitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.habitLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          Habit,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (Habit, $$HabitsTableReferences),
          Habit,
          PrefetchHooks Function({bool habitLogsRefs})
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> templateKey = const Value.absent(),
                Value<String?> goalKey = const Value.absent(),
                Value<String?> areaKey = const Value.absent(),
                Value<String> timeOfDay = const Value.absent(),
                Value<String> repeatType = const Value.absent(),
                Value<String?> dueDay = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> scheduleType = const Value.absent(),
                Value<int> weekdaysMask = const Value.absent(),
                Value<int> targetPerDay = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                templateKey: templateKey,
                goalKey: goalKey,
                areaKey: areaKey,
                timeOfDay: timeOfDay,
                repeatType: repeatType,
                dueDay: dueDay,
                title: title,
                icon: icon,
                scheduleType: scheduleType,
                weekdaysMask: weekdaysMask,
                targetPerDay: targetPerDay,
                reminderMinutes: reminderMinutes,
                isCustom: isCustom,
                isLocked: isLocked,
                archivedAt: archivedAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> templateKey = const Value.absent(),
                Value<String?> goalKey = const Value.absent(),
                Value<String?> areaKey = const Value.absent(),
                Value<String> timeOfDay = const Value.absent(),
                Value<String> repeatType = const Value.absent(),
                Value<String?> dueDay = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> scheduleType = const Value.absent(),
                Value<int> weekdaysMask = const Value.absent(),
                Value<int> targetPerDay = const Value.absent(),
                Value<int?> reminderMinutes = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<bool> isLocked = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                templateKey: templateKey,
                goalKey: goalKey,
                areaKey: areaKey,
                timeOfDay: timeOfDay,
                repeatType: repeatType,
                dueDay: dueDay,
                title: title,
                icon: icon,
                scheduleType: scheduleType,
                weekdaysMask: weekdaysMask,
                targetPerDay: targetPerDay,
                reminderMinutes: reminderMinutes,
                isCustom: isCustom,
                isLocked: isLocked,
                archivedAt: archivedAt,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitsTable, Habit>(table),
                  $$HabitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({habitLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (habitLogsRefs) db.habitLogs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (habitLogsRefs)
                    await $_getPrefetchedData<Habit, $HabitsTable, HabitLog>(
                      currentTable: table,
                      referencedTable: $$HabitsTableReferences
                          ._habitLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$HabitsTableReferences(db, table, p0).habitLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.habitId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      Habit,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (Habit, $$HabitsTableReferences),
      Habit,
      PrefetchHooks Function({bool habitLogsRefs})
    >;
typedef $$HabitLogsTableCreateCompanionBuilder = HabitLogsCompanion Function({
  required String id,
  required String habitId,
  required String localDay,
  Value<int> count,
  required int completedAt,
  Value<String> source,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$HabitLogsTableUpdateCompanionBuilder = HabitLogsCompanion Function({
  Value<String> id,
  Value<String> habitId,
  Value<String> localDay,
  Value<int> count,
  Value<int> completedAt,
  Value<String> source,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

final class $$HabitLogsTableReferences
    extends BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLog> {
  $$HabitLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HabitsTable _habitIdTable(_$AppDatabase db) =>
      db.habits.createAlias('habit_logs__habit_id__habits__id');

  $$HabitsTableProcessedTableManager get habitId {
    final $_column = $_itemColumn<String>('habit_id')!;

    final manager = $$HabitsTableTableManager(
      $_db,
      $_db.habits,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_habitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HabitLogsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HabitsTableFilterComposer get habitId {
    final $$HabitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitId,
      referencedTable: $db.habits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitsTableFilterComposer(
            $db: $db,
            $table: $db.habits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HabitLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HabitsTableOrderingComposer get habitId {
    final $$HabitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitId,
      referencedTable: $db.habits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitsTableOrderingComposer(
            $db: $db,
            $table: $db.habits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HabitLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$HabitsTableAnnotationComposer get habitId {
    final $$HabitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitId,
      referencedTable: $db.habits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitsTableAnnotationComposer(
            $db: $db,
            $table: $db.habits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HabitLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitLogsTable,
          HabitLog,
          $$HabitLogsTableFilterComposer,
          $$HabitLogsTableOrderingComposer,
          $$HabitLogsTableAnnotationComposer,
          $$HabitLogsTableCreateCompanionBuilder,
          $$HabitLogsTableUpdateCompanionBuilder,
          (HabitLog, $$HabitLogsTableReferences),
          HabitLog,
          PrefetchHooks Function({bool habitId})
        > {
  $$HabitLogsTableTableManager(_$AppDatabase db, $HabitLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> completedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion(
                id: id,
                habitId: habitId,
                localDay: localDay,
                count: count,
                completedAt: completedAt,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required String localDay,
                Value<int> count = const Value.absent(),
                required int completedAt,
                Value<String> source = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion.insert(
                id: id,
                habitId: habitId,
                localDay: localDay,
                count: count,
                completedAt: completedAt,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitLogsTable, HabitLog>(table),
                  $$HabitLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({habitId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (habitId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.habitId,
                        referencedTable: $$HabitLogsTableReferences
                            ._habitIdTable(db),
                        referencedColumn: $$HabitLogsTableReferences
                            ._habitIdTable(db)
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
        ),
      );
}

typedef $$HabitLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitLogsTable,
      HabitLog,
      $$HabitLogsTableFilterComposer,
      $$HabitLogsTableOrderingComposer,
      $$HabitLogsTableAnnotationComposer,
      $$HabitLogsTableCreateCompanionBuilder,
      $$HabitLogsTableUpdateCompanionBuilder,
      (HabitLog, $$HabitLogsTableReferences),
      HabitLog,
      PrefetchHooks Function({bool habitId})
    >;
typedef $$CheckinsTableCreateCompanionBuilder = CheckinsCompanion Function({
  required String id,
  required String localDay,
  required int moodLevel,
  Value<String?> note,
  Value<String?> tags,
  Value<String> source,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});
typedef $$CheckinsTableUpdateCompanionBuilder = CheckinsCompanion Function({
  Value<String> id,
  Value<String> localDay,
  Value<int> moodLevel,
  Value<String?> note,
  Value<String?> tags,
  Value<String> source,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<int> rowid,
});

class $$CheckinsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckinsTable> {
  $$CheckinsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moodLevel => $composableBuilder(
    column: $table.moodLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CheckinsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckinsTable> {
  $$CheckinsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moodLevel => $composableBuilder(
    column: $table.moodLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CheckinsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckinsTable> {
  $$CheckinsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<int> get moodLevel =>
      $composableBuilder(column: $table.moodLevel, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CheckinsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CheckinsTable,
          Checkin,
          $$CheckinsTableFilterComposer,
          $$CheckinsTableOrderingComposer,
          $$CheckinsTableAnnotationComposer,
          $$CheckinsTableCreateCompanionBuilder,
          $$CheckinsTableUpdateCompanionBuilder,
          (Checkin, BaseReferences<_$AppDatabase, $CheckinsTable, Checkin>),
          Checkin,
          PrefetchHooks Function()
        > {
  $$CheckinsTableTableManager(_$AppDatabase db, $CheckinsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckinsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckinsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckinsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<int> moodLevel = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckinsCompanion(
                id: id,
                localDay: localDay,
                moodLevel: moodLevel,
                note: note,
                tags: tags,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String localDay,
                required int moodLevel,
                Value<String?> note = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<String> source = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckinsCompanion.insert(
                id: id,
                localDay: localDay,
                moodLevel: moodLevel,
                note: note,
                tags: tags,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CheckinsTable, Checkin>(table),
                  BaseReferences<_$AppDatabase, $CheckinsTable, Checkin>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CheckinsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CheckinsTable,
      Checkin,
      $$CheckinsTableFilterComposer,
      $$CheckinsTableOrderingComposer,
      $$CheckinsTableAnnotationComposer,
      $$CheckinsTableCreateCompanionBuilder,
      $$CheckinsTableUpdateCompanionBuilder,
      (Checkin, BaseReferences<_$AppDatabase, $CheckinsTable, Checkin>),
      Checkin,
      PrefetchHooks Function()
    >;
typedef $$ExerciseSessionsTableCreateCompanionBuilder =
    ExerciseSessionsCompanion Function({
      required String id,
      required String exerciseKey,
      required int startedAt,
      Value<int?> completedAt,
      Value<int> durationS,
      required String localDay,
      Value<String?> journalText,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$ExerciseSessionsTableUpdateCompanionBuilder =
    ExerciseSessionsCompanion Function({
      Value<String> id,
      Value<String> exerciseKey,
      Value<int> startedAt,
      Value<int?> completedAt,
      Value<int> durationS,
      Value<String> localDay,
      Value<String?> journalText,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$ExerciseSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseSessionsTable> {
  $$ExerciseSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationS => $composableBuilder(
    column: $table.durationS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get journalText => $composableBuilder(
    column: $table.journalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExerciseSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseSessionsTable> {
  $$ExerciseSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationS => $composableBuilder(
    column: $table.durationS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get journalText => $composableBuilder(
    column: $table.journalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseSessionsTable> {
  $$ExerciseSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get exerciseKey => $composableBuilder(
    column: $table.exerciseKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationS =>
      $composableBuilder(column: $table.durationS, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<String> get journalText => $composableBuilder(
    column: $table.journalText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ExerciseSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseSessionsTable,
          ExerciseSession,
          $$ExerciseSessionsTableFilterComposer,
          $$ExerciseSessionsTableOrderingComposer,
          $$ExerciseSessionsTableAnnotationComposer,
          $$ExerciseSessionsTableCreateCompanionBuilder,
          $$ExerciseSessionsTableUpdateCompanionBuilder,
          (
            ExerciseSession,
            BaseReferences<
              _$AppDatabase,
              $ExerciseSessionsTable,
              ExerciseSession
            >,
          ),
          ExerciseSession,
          PrefetchHooks Function()
        > {
  $$ExerciseSessionsTableTableManager(
    _$AppDatabase db,
    $ExerciseSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> exerciseKey = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> durationS = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<String?> journalText = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseSessionsCompanion(
                id: id,
                exerciseKey: exerciseKey,
                startedAt: startedAt,
                completedAt: completedAt,
                durationS: durationS,
                localDay: localDay,
                journalText: journalText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String exerciseKey,
                required int startedAt,
                Value<int?> completedAt = const Value.absent(),
                Value<int> durationS = const Value.absent(),
                required String localDay,
                Value<String?> journalText = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExerciseSessionsCompanion.insert(
                id: id,
                exerciseKey: exerciseKey,
                startedAt: startedAt,
                completedAt: completedAt,
                durationS: durationS,
                localDay: localDay,
                journalText: journalText,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExerciseSessionsTable, ExerciseSession>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ExerciseSessionsTable,
                    ExerciseSession
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExerciseSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseSessionsTable,
      ExerciseSession,
      $$ExerciseSessionsTableFilterComposer,
      $$ExerciseSessionsTableOrderingComposer,
      $$ExerciseSessionsTableAnnotationComposer,
      $$ExerciseSessionsTableCreateCompanionBuilder,
      $$ExerciseSessionsTableUpdateCompanionBuilder,
      (
        ExerciseSession,
        BaseReferences<_$AppDatabase, $ExerciseSessionsTable, ExerciseSession>,
      ),
      ExerciseSession,
      PrefetchHooks Function()
    >;
typedef $$WalletTableCreateCompanionBuilder = WalletCompanion Function({
  Value<int> id,
  Value<int> energy,
  Value<int> coins,
  required int updatedAt,
});
typedef $$WalletTableUpdateCompanionBuilder = WalletCompanion Function({
  Value<int> id,
  Value<int> energy,
  Value<int> coins,
  Value<int> updatedAt,
});

class $$WalletTableFilterComposer
    extends Composer<_$AppDatabase, $WalletTable> {
  $$WalletTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletTable> {
  $$WalletTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energy => $composableBuilder(
    column: $table.energy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletTable> {
  $$WalletTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get energy =>
      $composableBuilder(column: $table.energy, builder: (column) => column);

  GeneratedColumn<int> get coins =>
      $composableBuilder(column: $table.coins, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WalletTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletTable,
          WalletData,
          $$WalletTableFilterComposer,
          $$WalletTableOrderingComposer,
          $$WalletTableAnnotationComposer,
          $$WalletTableCreateCompanionBuilder,
          $$WalletTableUpdateCompanionBuilder,
          (WalletData, BaseReferences<_$AppDatabase, $WalletTable, WalletData>),
          WalletData,
          PrefetchHooks Function()
        > {
  $$WalletTableTableManager(_$AppDatabase db, $WalletTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> energy = const Value.absent(),
                Value<int> coins = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => WalletCompanion(
                id: id,
                energy: energy,
                coins: coins,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> energy = const Value.absent(),
                Value<int> coins = const Value.absent(),
                required int updatedAt,
              }) => WalletCompanion.insert(
                id: id,
                energy: energy,
                coins: coins,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WalletTable, WalletData>(table),
                  BaseReferences<_$AppDatabase, $WalletTable, WalletData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletTable,
      WalletData,
      $$WalletTableFilterComposer,
      $$WalletTableOrderingComposer,
      $$WalletTableAnnotationComposer,
      $$WalletTableCreateCompanionBuilder,
      $$WalletTableUpdateCompanionBuilder,
      (WalletData, BaseReferences<_$AppDatabase, $WalletTable, WalletData>),
      WalletData,
      PrefetchHooks Function()
    >;
typedef $$WalletLedgerTableCreateCompanionBuilder =
    WalletLedgerCompanion Function({
      required String id,
      required String currency,
      required int delta,
      required String reason,
      required String refId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$WalletLedgerTableUpdateCompanionBuilder =
    WalletLedgerCompanion Function({
      Value<String> id,
      Value<String> currency,
      Value<int> delta,
      Value<String> reason,
      Value<String> refId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$WalletLedgerTableFilterComposer
    extends Composer<_$AppDatabase, $WalletLedgerTable> {
  $$WalletLedgerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletLedgerTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletLedgerTable> {
  $$WalletLedgerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletLedgerTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletLedgerTable> {
  $$WalletLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get delta =>
      $composableBuilder(column: $table.delta, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WalletLedgerTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletLedgerTable,
          WalletLedgerData,
          $$WalletLedgerTableFilterComposer,
          $$WalletLedgerTableOrderingComposer,
          $$WalletLedgerTableAnnotationComposer,
          $$WalletLedgerTableCreateCompanionBuilder,
          $$WalletLedgerTableUpdateCompanionBuilder,
          (
            WalletLedgerData,
            BaseReferences<_$AppDatabase, $WalletLedgerTable, WalletLedgerData>,
          ),
          WalletLedgerData,
          PrefetchHooks Function()
        > {
  $$WalletLedgerTableTableManager(_$AppDatabase db, $WalletLedgerTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletLedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> delta = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> refId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletLedgerCompanion(
                id: id,
                currency: currency,
                delta: delta,
                reason: reason,
                refId: refId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String currency,
                required int delta,
                required String reason,
                required String refId,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WalletLedgerCompanion.insert(
                id: id,
                currency: currency,
                delta: delta,
                reason: reason,
                refId: refId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WalletLedgerTable, WalletLedgerData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WalletLedgerTable,
                    WalletLedgerData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletLedgerTable,
      WalletLedgerData,
      $$WalletLedgerTableFilterComposer,
      $$WalletLedgerTableOrderingComposer,
      $$WalletLedgerTableAnnotationComposer,
      $$WalletLedgerTableCreateCompanionBuilder,
      $$WalletLedgerTableUpdateCompanionBuilder,
      (
        WalletLedgerData,
        BaseReferences<_$AppDatabase, $WalletLedgerTable, WalletLedgerData>,
      ),
      WalletLedgerData,
      PrefetchHooks Function()
    >;
typedef $$AdventuresTableCreateCompanionBuilder = AdventuresCompanion Function({
  required String id,
  required String locationKey,
  required int energyCost,
  required int startedAt,
  required int endsAt,
  Value<String> status,
  Value<int> rewardCoins,
  Value<String?> rewardItemKey,
  Value<String?> storyKey,
  Value<int?> claimedAt,
  Value<int> rowid,
});
typedef $$AdventuresTableUpdateCompanionBuilder = AdventuresCompanion Function({
  Value<String> id,
  Value<String> locationKey,
  Value<int> energyCost,
  Value<int> startedAt,
  Value<int> endsAt,
  Value<String> status,
  Value<int> rewardCoins,
  Value<String?> rewardItemKey,
  Value<String?> storyKey,
  Value<int?> claimedAt,
  Value<int> rowid,
});

class $$AdventuresTableFilterComposer
    extends Composer<_$AppDatabase, $AdventuresTable> {
  $$AdventuresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationKey => $composableBuilder(
    column: $table.locationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energyCost => $composableBuilder(
    column: $table.energyCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rewardCoins => $composableBuilder(
    column: $table.rewardCoins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rewardItemKey => $composableBuilder(
    column: $table.rewardItemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storyKey => $composableBuilder(
    column: $table.storyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AdventuresTableOrderingComposer
    extends Composer<_$AppDatabase, $AdventuresTable> {
  $$AdventuresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationKey => $composableBuilder(
    column: $table.locationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energyCost => $composableBuilder(
    column: $table.energyCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rewardCoins => $composableBuilder(
    column: $table.rewardCoins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewardItemKey => $composableBuilder(
    column: $table.rewardItemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storyKey => $composableBuilder(
    column: $table.storyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AdventuresTableAnnotationComposer
    extends Composer<_$AppDatabase, $AdventuresTable> {
  $$AdventuresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locationKey => $composableBuilder(
    column: $table.locationKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get energyCost => $composableBuilder(
    column: $table.energyCost,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get rewardCoins => $composableBuilder(
    column: $table.rewardCoins,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rewardItemKey => $composableBuilder(
    column: $table.rewardItemKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storyKey =>
      $composableBuilder(column: $table.storyKey, builder: (column) => column);

  GeneratedColumn<int> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);
}

class $$AdventuresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AdventuresTable,
          Adventure,
          $$AdventuresTableFilterComposer,
          $$AdventuresTableOrderingComposer,
          $$AdventuresTableAnnotationComposer,
          $$AdventuresTableCreateCompanionBuilder,
          $$AdventuresTableUpdateCompanionBuilder,
          (
            Adventure,
            BaseReferences<_$AppDatabase, $AdventuresTable, Adventure>,
          ),
          Adventure,
          PrefetchHooks Function()
        > {
  $$AdventuresTableTableManager(_$AppDatabase db, $AdventuresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdventuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdventuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdventuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> locationKey = const Value.absent(),
                Value<int> energyCost = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int> endsAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rewardCoins = const Value.absent(),
                Value<String?> rewardItemKey = const Value.absent(),
                Value<String?> storyKey = const Value.absent(),
                Value<int?> claimedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdventuresCompanion(
                id: id,
                locationKey: locationKey,
                energyCost: energyCost,
                startedAt: startedAt,
                endsAt: endsAt,
                status: status,
                rewardCoins: rewardCoins,
                rewardItemKey: rewardItemKey,
                storyKey: storyKey,
                claimedAt: claimedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String locationKey,
                required int energyCost,
                required int startedAt,
                required int endsAt,
                Value<String> status = const Value.absent(),
                Value<int> rewardCoins = const Value.absent(),
                Value<String?> rewardItemKey = const Value.absent(),
                Value<String?> storyKey = const Value.absent(),
                Value<int?> claimedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdventuresCompanion.insert(
                id: id,
                locationKey: locationKey,
                energyCost: energyCost,
                startedAt: startedAt,
                endsAt: endsAt,
                status: status,
                rewardCoins: rewardCoins,
                rewardItemKey: rewardItemKey,
                storyKey: storyKey,
                claimedAt: claimedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AdventuresTable, Adventure>(table),
                  BaseReferences<_$AppDatabase, $AdventuresTable, Adventure>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AdventuresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AdventuresTable,
      Adventure,
      $$AdventuresTableFilterComposer,
      $$AdventuresTableOrderingComposer,
      $$AdventuresTableAnnotationComposer,
      $$AdventuresTableCreateCompanionBuilder,
      $$AdventuresTableUpdateCompanionBuilder,
      (Adventure, BaseReferences<_$AppDatabase, $AdventuresTable, Adventure>),
      Adventure,
      PrefetchHooks Function()
    >;
typedef $$InventoryTableCreateCompanionBuilder = InventoryCompanion Function({
  required String itemKey,
  required int acquiredAt,
  required String source,
  Value<bool> equipped,
  required String slot,
  Value<int> rowid,
});
typedef $$InventoryTableUpdateCompanionBuilder = InventoryCompanion Function({
  Value<String> itemKey,
  Value<int> acquiredAt,
  Value<String> source,
  Value<bool> equipped,
  Value<String> slot,
  Value<int> rowid,
});

class $$InventoryTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryTable> {
  $$InventoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get equipped => $composableBuilder(
    column: $table.equipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InventoryTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryTable> {
  $$InventoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get equipped => $composableBuilder(
    column: $table.equipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InventoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryTable> {
  $$InventoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

  GeneratedColumn<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get equipped =>
      $composableBuilder(column: $table.equipped, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);
}

class $$InventoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InventoryTable,
          InventoryData,
          $$InventoryTableFilterComposer,
          $$InventoryTableOrderingComposer,
          $$InventoryTableAnnotationComposer,
          $$InventoryTableCreateCompanionBuilder,
          $$InventoryTableUpdateCompanionBuilder,
          (
            InventoryData,
            BaseReferences<_$AppDatabase, $InventoryTable, InventoryData>,
          ),
          InventoryData,
          PrefetchHooks Function()
        > {
  $$InventoryTableTableManager(_$AppDatabase db, $InventoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemKey = const Value.absent(),
                Value<int> acquiredAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> equipped = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventoryCompanion(
                itemKey: itemKey,
                acquiredAt: acquiredAt,
                source: source,
                equipped: equipped,
                slot: slot,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemKey,
                required int acquiredAt,
                required String source,
                Value<bool> equipped = const Value.absent(),
                required String slot,
                Value<int> rowid = const Value.absent(),
              }) => InventoryCompanion.insert(
                itemKey: itemKey,
                acquiredAt: acquiredAt,
                source: source,
                equipped: equipped,
                slot: slot,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InventoryTable, InventoryData>(table),
                  BaseReferences<_$AppDatabase, $InventoryTable, InventoryData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InventoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InventoryTable,
      InventoryData,
      $$InventoryTableFilterComposer,
      $$InventoryTableOrderingComposer,
      $$InventoryTableAnnotationComposer,
      $$InventoryTableCreateCompanionBuilder,
      $$InventoryTableUpdateCompanionBuilder,
      (
        InventoryData,
        BaseReferences<_$AppDatabase, $InventoryTable, InventoryData>,
      ),
      InventoryData,
      PrefetchHooks Function()
    >;
typedef $$StreakStateTableCreateCompanionBuilder =
    StreakStateCompanion Function({
      Value<int> id,
      Value<int> current,
      Value<int> longest,
      Value<String?> lastActiveDay,
      Value<int> freezesLeft,
      Value<String?> freezeMonth,
    });
typedef $$StreakStateTableUpdateCompanionBuilder =
    StreakStateCompanion Function({
      Value<int> id,
      Value<int> current,
      Value<int> longest,
      Value<String?> lastActiveDay,
      Value<int> freezesLeft,
      Value<String?> freezeMonth,
    });

class $$StreakStateTableFilterComposer
    extends Composer<_$AppDatabase, $StreakStateTable> {
  $$StreakStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longest => $composableBuilder(
    column: $table.longest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastActiveDay => $composableBuilder(
    column: $table.lastActiveDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freezesLeft => $composableBuilder(
    column: $table.freezesLeft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get freezeMonth => $composableBuilder(
    column: $table.freezeMonth,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StreakStateTableOrderingComposer
    extends Composer<_$AppDatabase, $StreakStateTable> {
  $$StreakStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get current => $composableBuilder(
    column: $table.current,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longest => $composableBuilder(
    column: $table.longest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastActiveDay => $composableBuilder(
    column: $table.lastActiveDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freezesLeft => $composableBuilder(
    column: $table.freezesLeft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get freezeMonth => $composableBuilder(
    column: $table.freezeMonth,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StreakStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreakStateTable> {
  $$StreakStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get current =>
      $composableBuilder(column: $table.current, builder: (column) => column);

  GeneratedColumn<int> get longest =>
      $composableBuilder(column: $table.longest, builder: (column) => column);

  GeneratedColumn<String> get lastActiveDay => $composableBuilder(
    column: $table.lastActiveDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get freezesLeft => $composableBuilder(
    column: $table.freezesLeft,
    builder: (column) => column,
  );

  GeneratedColumn<String> get freezeMonth => $composableBuilder(
    column: $table.freezeMonth,
    builder: (column) => column,
  );
}

class $$StreakStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StreakStateTable,
          StreakStateData,
          $$StreakStateTableFilterComposer,
          $$StreakStateTableOrderingComposer,
          $$StreakStateTableAnnotationComposer,
          $$StreakStateTableCreateCompanionBuilder,
          $$StreakStateTableUpdateCompanionBuilder,
          (
            StreakStateData,
            BaseReferences<_$AppDatabase, $StreakStateTable, StreakStateData>,
          ),
          StreakStateData,
          PrefetchHooks Function()
        > {
  $$StreakStateTableTableManager(_$AppDatabase db, $StreakStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> current = const Value.absent(),
                Value<int> longest = const Value.absent(),
                Value<String?> lastActiveDay = const Value.absent(),
                Value<int> freezesLeft = const Value.absent(),
                Value<String?> freezeMonth = const Value.absent(),
              }) => StreakStateCompanion(
                id: id,
                current: current,
                longest: longest,
                lastActiveDay: lastActiveDay,
                freezesLeft: freezesLeft,
                freezeMonth: freezeMonth,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> current = const Value.absent(),
                Value<int> longest = const Value.absent(),
                Value<String?> lastActiveDay = const Value.absent(),
                Value<int> freezesLeft = const Value.absent(),
                Value<String?> freezeMonth = const Value.absent(),
              }) => StreakStateCompanion.insert(
                id: id,
                current: current,
                longest: longest,
                lastActiveDay: lastActiveDay,
                freezesLeft: freezesLeft,
                freezeMonth: freezeMonth,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StreakStateTable, StreakStateData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $StreakStateTable,
                    StreakStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StreakStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StreakStateTable,
      StreakStateData,
      $$StreakStateTableFilterComposer,
      $$StreakStateTableOrderingComposer,
      $$StreakStateTableAnnotationComposer,
      $$StreakStateTableCreateCompanionBuilder,
      $$StreakStateTableUpdateCompanionBuilder,
      (
        StreakStateData,
        BaseReferences<_$AppDatabase, $StreakStateTable, StreakStateData>,
      ),
      StreakStateData,
      PrefetchHooks Function()
    >;
typedef $$SafetyFlagsTableCreateCompanionBuilder =
    SafetyFlagsCompanion Function({
      required String id,
      required String localDay,
      required String kind,
      Value<int?> shownAt,
      Value<int?> dismissedAt,
      Value<int> rowid,
    });
typedef $$SafetyFlagsTableUpdateCompanionBuilder =
    SafetyFlagsCompanion Function({
      Value<String> id,
      Value<String> localDay,
      Value<String> kind,
      Value<int?> shownAt,
      Value<int?> dismissedAt,
      Value<int> rowid,
    });

class $$SafetyFlagsTableFilterComposer
    extends Composer<_$AppDatabase, $SafetyFlagsTable> {
  $$SafetyFlagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shownAt => $composableBuilder(
    column: $table.shownAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SafetyFlagsTableOrderingComposer
    extends Composer<_$AppDatabase, $SafetyFlagsTable> {
  $$SafetyFlagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shownAt => $composableBuilder(
    column: $table.shownAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SafetyFlagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SafetyFlagsTable> {
  $$SafetyFlagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get shownAt =>
      $composableBuilder(column: $table.shownAt, builder: (column) => column);

  GeneratedColumn<int> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );
}

class $$SafetyFlagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SafetyFlagsTable,
          SafetyFlag,
          $$SafetyFlagsTableFilterComposer,
          $$SafetyFlagsTableOrderingComposer,
          $$SafetyFlagsTableAnnotationComposer,
          $$SafetyFlagsTableCreateCompanionBuilder,
          $$SafetyFlagsTableUpdateCompanionBuilder,
          (
            SafetyFlag,
            BaseReferences<_$AppDatabase, $SafetyFlagsTable, SafetyFlag>,
          ),
          SafetyFlag,
          PrefetchHooks Function()
        > {
  $$SafetyFlagsTableTableManager(_$AppDatabase db, $SafetyFlagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SafetyFlagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SafetyFlagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SafetyFlagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> shownAt = const Value.absent(),
                Value<int?> dismissedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SafetyFlagsCompanion(
                id: id,
                localDay: localDay,
                kind: kind,
                shownAt: shownAt,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String localDay,
                required String kind,
                Value<int?> shownAt = const Value.absent(),
                Value<int?> dismissedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SafetyFlagsCompanion.insert(
                id: id,
                localDay: localDay,
                kind: kind,
                shownAt: shownAt,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SafetyFlagsTable, SafetyFlag>(table),
                  BaseReferences<_$AppDatabase, $SafetyFlagsTable, SafetyFlag>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SafetyFlagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SafetyFlagsTable,
      SafetyFlag,
      $$SafetyFlagsTableFilterComposer,
      $$SafetyFlagsTableOrderingComposer,
      $$SafetyFlagsTableAnnotationComposer,
      $$SafetyFlagsTableCreateCompanionBuilder,
      $$SafetyFlagsTableUpdateCompanionBuilder,
      (
        SafetyFlag,
        BaseReferences<_$AppDatabase, $SafetyFlagsTable, SafetyFlag>,
      ),
      SafetyFlag,
      PrefetchHooks Function()
    >;
typedef $$NotificationLogTableCreateCompanionBuilder =
    NotificationLogCompanion Function({
      required String id,
      required String type,
      required int scheduledFor,
      Value<int?> deliveredAt,
      Value<int?> openedAt,
      Value<int> rowid,
    });
typedef $$NotificationLogTableUpdateCompanionBuilder =
    NotificationLogCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<int> scheduledFor,
      Value<int?> deliveredAt,
      Value<int?> openedAt,
      Value<int> rowid,
    });

class $$NotificationLogTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationLogTable> {
  $$NotificationLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationLogTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationLogTable> {
  $$NotificationLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationLogTable> {
  $$NotificationLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);
}

class $$NotificationLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationLogTable,
          NotificationLogData,
          $$NotificationLogTableFilterComposer,
          $$NotificationLogTableOrderingComposer,
          $$NotificationLogTableAnnotationComposer,
          $$NotificationLogTableCreateCompanionBuilder,
          $$NotificationLogTableUpdateCompanionBuilder,
          (
            NotificationLogData,
            BaseReferences<
              _$AppDatabase,
              $NotificationLogTable,
              NotificationLogData
            >,
          ),
          NotificationLogData,
          PrefetchHooks Function()
        > {
  $$NotificationLogTableTableManager(
    _$AppDatabase db,
    $NotificationLogTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> scheduledFor = const Value.absent(),
                Value<int?> deliveredAt = const Value.absent(),
                Value<int?> openedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationLogCompanion(
                id: id,
                type: type,
                scheduledFor: scheduledFor,
                deliveredAt: deliveredAt,
                openedAt: openedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required int scheduledFor,
                Value<int?> deliveredAt = const Value.absent(),
                Value<int?> openedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationLogCompanion.insert(
                id: id,
                type: type,
                scheduledFor: scheduledFor,
                deliveredAt: deliveredAt,
                openedAt: openedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotificationLogTable, NotificationLogData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $NotificationLogTable,
                    NotificationLogData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationLogTable,
      NotificationLogData,
      $$NotificationLogTableFilterComposer,
      $$NotificationLogTableOrderingComposer,
      $$NotificationLogTableAnnotationComposer,
      $$NotificationLogTableCreateCompanionBuilder,
      $$NotificationLogTableUpdateCompanionBuilder,
      (
        NotificationLogData,
        BaseReferences<
          _$AppDatabase,
          $NotificationLogTable,
          NotificationLogData
        >,
      ),
      NotificationLogData,
      PrefetchHooks Function()
    >;
typedef $$EntitlementCacheTableCreateCompanionBuilder =
    EntitlementCacheCompanion Function({
      Value<int> id,
      required String stateJson,
      required String signature,
      required String kid,
      required int fetchedAt,
      Value<int?> pendingVerificationUntil,
    });
typedef $$EntitlementCacheTableUpdateCompanionBuilder =
    EntitlementCacheCompanion Function({
      Value<int> id,
      Value<String> stateJson,
      Value<String> signature,
      Value<String> kid,
      Value<int> fetchedAt,
      Value<int?> pendingVerificationUntil,
    });

class $$EntitlementCacheTableFilterComposer
    extends Composer<_$AppDatabase, $EntitlementCacheTable> {
  $$EntitlementCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kid => $composableBuilder(
    column: $table.kid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingVerificationUntil => $composableBuilder(
    column: $table.pendingVerificationUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EntitlementCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $EntitlementCacheTable> {
  $$EntitlementCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kid => $composableBuilder(
    column: $table.kid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingVerificationUntil => $composableBuilder(
    column: $table.pendingVerificationUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EntitlementCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntitlementCacheTable> {
  $$EntitlementCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stateJson =>
      $composableBuilder(column: $table.stateJson, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<String> get kid =>
      $composableBuilder(column: $table.kid, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<int> get pendingVerificationUntil => $composableBuilder(
    column: $table.pendingVerificationUntil,
    builder: (column) => column,
  );
}

class $$EntitlementCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntitlementCacheTable,
          EntitlementCacheData,
          $$EntitlementCacheTableFilterComposer,
          $$EntitlementCacheTableOrderingComposer,
          $$EntitlementCacheTableAnnotationComposer,
          $$EntitlementCacheTableCreateCompanionBuilder,
          $$EntitlementCacheTableUpdateCompanionBuilder,
          (
            EntitlementCacheData,
            BaseReferences<
              _$AppDatabase,
              $EntitlementCacheTable,
              EntitlementCacheData
            >,
          ),
          EntitlementCacheData,
          PrefetchHooks Function()
        > {
  $$EntitlementCacheTableTableManager(
    _$AppDatabase db,
    $EntitlementCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntitlementCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntitlementCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntitlementCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> stateJson = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<String> kid = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int?> pendingVerificationUntil = const Value.absent(),
              }) => EntitlementCacheCompanion(
                id: id,
                stateJson: stateJson,
                signature: signature,
                kid: kid,
                fetchedAt: fetchedAt,
                pendingVerificationUntil: pendingVerificationUntil,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String stateJson,
                required String signature,
                required String kid,
                required int fetchedAt,
                Value<int?> pendingVerificationUntil = const Value.absent(),
              }) => EntitlementCacheCompanion.insert(
                id: id,
                stateJson: stateJson,
                signature: signature,
                kid: kid,
                fetchedAt: fetchedAt,
                pendingVerificationUntil: pendingVerificationUntil,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntitlementCacheTable, EntitlementCacheData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $EntitlementCacheTable,
                    EntitlementCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EntitlementCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntitlementCacheTable,
      EntitlementCacheData,
      $$EntitlementCacheTableFilterComposer,
      $$EntitlementCacheTableOrderingComposer,
      $$EntitlementCacheTableAnnotationComposer,
      $$EntitlementCacheTableCreateCompanionBuilder,
      $$EntitlementCacheTableUpdateCompanionBuilder,
      (
        EntitlementCacheData,
        BaseReferences<
          _$AppDatabase,
          $EntitlementCacheTable,
          EntitlementCacheData
        >,
      ),
      EntitlementCacheData,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String id,
  required String kind,
  required String payload,
  Value<int> attempts,
  required int nextAttemptAt,
  Value<String?> lastError,
  required int createdAt,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> payload,
  Value<int> attempts,
  Value<int> nextAttemptAt,
  Value<String?> lastError,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                kind: kind,
                payload: payload,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String payload,
                Value<int> attempts = const Value.absent(),
                required int nextAttemptAt,
                Value<String?> lastError = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                kind: kind,
                payload: payload,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxData>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$AnalyticsQueueTableCreateCompanionBuilder =
    AnalyticsQueueCompanion Function({
      required String id,
      required String name,
      required String props,
      required int ts,
      required String sessionId,
      Value<int> rowid,
    });
typedef $$AnalyticsQueueTableUpdateCompanionBuilder =
    AnalyticsQueueCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> props,
      Value<int> ts,
      Value<String> sessionId,
      Value<int> rowid,
    });

class $$AnalyticsQueueTableFilterComposer
    extends Composer<_$AppDatabase, $AnalyticsQueueTable> {
  $$AnalyticsQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get props => $composableBuilder(
    column: $table.props,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalyticsQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalyticsQueueTable> {
  $$AnalyticsQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get props => $composableBuilder(
    column: $table.props,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalyticsQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalyticsQueueTable> {
  $$AnalyticsQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get props =>
      $composableBuilder(column: $table.props, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);
}

class $$AnalyticsQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalyticsQueueTable,
          AnalyticsQueueData,
          $$AnalyticsQueueTableFilterComposer,
          $$AnalyticsQueueTableOrderingComposer,
          $$AnalyticsQueueTableAnnotationComposer,
          $$AnalyticsQueueTableCreateCompanionBuilder,
          $$AnalyticsQueueTableUpdateCompanionBuilder,
          (
            AnalyticsQueueData,
            BaseReferences<
              _$AppDatabase,
              $AnalyticsQueueTable,
              AnalyticsQueueData
            >,
          ),
          AnalyticsQueueData,
          PrefetchHooks Function()
        > {
  $$AnalyticsQueueTableTableManager(
    _$AppDatabase db,
    $AnalyticsQueueTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalyticsQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalyticsQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalyticsQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> props = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalyticsQueueCompanion(
                id: id,
                name: name,
                props: props,
                ts: ts,
                sessionId: sessionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String props,
                required int ts,
                required String sessionId,
                Value<int> rowid = const Value.absent(),
              }) => AnalyticsQueueCompanion.insert(
                id: id,
                name: name,
                props: props,
                ts: ts,
                sessionId: sessionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnalyticsQueueTable, AnalyticsQueueData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AnalyticsQueueTable,
                    AnalyticsQueueData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnalyticsQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalyticsQueueTable,
      AnalyticsQueueData,
      $$AnalyticsQueueTableFilterComposer,
      $$AnalyticsQueueTableOrderingComposer,
      $$AnalyticsQueueTableAnnotationComposer,
      $$AnalyticsQueueTableCreateCompanionBuilder,
      $$AnalyticsQueueTableUpdateCompanionBuilder,
      (
        AnalyticsQueueData,
        BaseReferences<_$AppDatabase, $AnalyticsQueueTable, AnalyticsQueueData>,
      ),
      AnalyticsQueueData,
      PrefetchHooks Function()
    >;
typedef $$ContentCacheTableCreateCompanionBuilder =
    ContentCacheCompanion Function({
      required String packKey,
      required int version,
      required String sha256,
      required String payload,
      Value<int> rowid,
    });
typedef $$ContentCacheTableUpdateCompanionBuilder =
    ContentCacheCompanion Function({
      Value<String> packKey,
      Value<int> version,
      Value<String> sha256,
      Value<String> payload,
      Value<int> rowid,
    });

class $$ContentCacheTableFilterComposer
    extends Composer<_$AppDatabase, $ContentCacheTable> {
  $$ContentCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get packKey => $composableBuilder(
    column: $table.packKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentCacheTable> {
  $$ContentCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get packKey => $composableBuilder(
    column: $table.packKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentCacheTable> {
  $$ContentCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get packKey =>
      $composableBuilder(column: $table.packKey, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$ContentCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentCacheTable,
          ContentCacheData,
          $$ContentCacheTableFilterComposer,
          $$ContentCacheTableOrderingComposer,
          $$ContentCacheTableAnnotationComposer,
          $$ContentCacheTableCreateCompanionBuilder,
          $$ContentCacheTableUpdateCompanionBuilder,
          (
            ContentCacheData,
            BaseReferences<_$AppDatabase, $ContentCacheTable, ContentCacheData>,
          ),
          ContentCacheData,
          PrefetchHooks Function()
        > {
  $$ContentCacheTableTableManager(_$AppDatabase db, $ContentCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> packKey = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentCacheCompanion(
                packKey: packKey,
                version: version,
                sha256: sha256,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String packKey,
                required int version,
                required String sha256,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => ContentCacheCompanion.insert(
                packKey: packKey,
                version: version,
                sha256: sha256,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentCacheTable, ContentCacheData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ContentCacheTable,
                    ContentCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentCacheTable,
      ContentCacheData,
      $$ContentCacheTableFilterComposer,
      $$ContentCacheTableOrderingComposer,
      $$ContentCacheTableAnnotationComposer,
      $$ContentCacheTableCreateCompanionBuilder,
      $$ContentCacheTableUpdateCompanionBuilder,
      (
        ContentCacheData,
        BaseReferences<_$AppDatabase, $ContentCacheTable, ContentCacheData>,
      ),
      ContentCacheData,
      PrefetchHooks Function()
    >;
typedef $$SupportMessagesCacheTableCreateCompanionBuilder =
    SupportMessagesCacheCompanion Function({
      required String id,
      Value<String?> clientMsgId,
      required String sender,
      required String body,
      required int createdAt,
      required String status,
      Value<int?> readAt,
      Value<String?> operatorName,
      Value<int> rowid,
    });
typedef $$SupportMessagesCacheTableUpdateCompanionBuilder =
    SupportMessagesCacheCompanion Function({
      Value<String> id,
      Value<String?> clientMsgId,
      Value<String> sender,
      Value<String> body,
      Value<int> createdAt,
      Value<String> status,
      Value<int?> readAt,
      Value<String?> operatorName,
      Value<int> rowid,
    });

class $$SupportMessagesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $SupportMessagesCacheTable> {
  $$SupportMessagesCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMsgId => $composableBuilder(
    column: $table.clientMsgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operatorName => $composableBuilder(
    column: $table.operatorName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SupportMessagesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $SupportMessagesCacheTable> {
  $$SupportMessagesCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMsgId => $composableBuilder(
    column: $table.clientMsgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operatorName => $composableBuilder(
    column: $table.operatorName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SupportMessagesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $SupportMessagesCacheTable> {
  $$SupportMessagesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientMsgId => $composableBuilder(
    column: $table.clientMsgId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<String> get operatorName => $composableBuilder(
    column: $table.operatorName,
    builder: (column) => column,
  );
}

class $$SupportMessagesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SupportMessagesCacheTable,
          SupportMessagesCacheData,
          $$SupportMessagesCacheTableFilterComposer,
          $$SupportMessagesCacheTableOrderingComposer,
          $$SupportMessagesCacheTableAnnotationComposer,
          $$SupportMessagesCacheTableCreateCompanionBuilder,
          $$SupportMessagesCacheTableUpdateCompanionBuilder,
          (
            SupportMessagesCacheData,
            BaseReferences<
              _$AppDatabase,
              $SupportMessagesCacheTable,
              SupportMessagesCacheData
            >,
          ),
          SupportMessagesCacheData,
          PrefetchHooks Function()
        > {
  $$SupportMessagesCacheTableTableManager(
    _$AppDatabase db,
    $SupportMessagesCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SupportMessagesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SupportMessagesCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SupportMessagesCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> clientMsgId = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> readAt = const Value.absent(),
                Value<String?> operatorName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SupportMessagesCacheCompanion(
                id: id,
                clientMsgId: clientMsgId,
                sender: sender,
                body: body,
                createdAt: createdAt,
                status: status,
                readAt: readAt,
                operatorName: operatorName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> clientMsgId = const Value.absent(),
                required String sender,
                required String body,
                required int createdAt,
                required String status,
                Value<int?> readAt = const Value.absent(),
                Value<String?> operatorName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SupportMessagesCacheCompanion.insert(
                id: id,
                clientMsgId: clientMsgId,
                sender: sender,
                body: body,
                createdAt: createdAt,
                status: status,
                readAt: readAt,
                operatorName: operatorName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SupportMessagesCacheTable,
                    SupportMessagesCacheData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SupportMessagesCacheTable,
                    SupportMessagesCacheData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SupportMessagesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SupportMessagesCacheTable,
      SupportMessagesCacheData,
      $$SupportMessagesCacheTableFilterComposer,
      $$SupportMessagesCacheTableOrderingComposer,
      $$SupportMessagesCacheTableAnnotationComposer,
      $$SupportMessagesCacheTableCreateCompanionBuilder,
      $$SupportMessagesCacheTableUpdateCompanionBuilder,
      (
        SupportMessagesCacheData,
        BaseReferences<
          _$AppDatabase,
          $SupportMessagesCacheTable,
          SupportMessagesCacheData
        >,
      ),
      SupportMessagesCacheData,
      PrefetchHooks Function()
    >;
typedef $$OnboardingAnswersTableCreateCompanionBuilder =
    OnboardingAnswersCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$OnboardingAnswersTableUpdateCompanionBuilder =
    OnboardingAnswersCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$OnboardingAnswersTableFilterComposer
    extends Composer<_$AppDatabase, $OnboardingAnswersTable> {
  $$OnboardingAnswersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnboardingAnswersTableOrderingComposer
    extends Composer<_$AppDatabase, $OnboardingAnswersTable> {
  $$OnboardingAnswersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnboardingAnswersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnboardingAnswersTable> {
  $$OnboardingAnswersTableAnnotationComposer({
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
}

class $$OnboardingAnswersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnboardingAnswersTable,
          OnboardingAnswer,
          $$OnboardingAnswersTableFilterComposer,
          $$OnboardingAnswersTableOrderingComposer,
          $$OnboardingAnswersTableAnnotationComposer,
          $$OnboardingAnswersTableCreateCompanionBuilder,
          $$OnboardingAnswersTableUpdateCompanionBuilder,
          (
            OnboardingAnswer,
            BaseReferences<
              _$AppDatabase,
              $OnboardingAnswersTable,
              OnboardingAnswer
            >,
          ),
          OnboardingAnswer,
          PrefetchHooks Function()
        > {
  $$OnboardingAnswersTableTableManager(
    _$AppDatabase db,
    $OnboardingAnswersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnboardingAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnboardingAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnboardingAnswersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnboardingAnswersCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => OnboardingAnswersCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OnboardingAnswersTable, OnboardingAnswer>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OnboardingAnswersTable,
                    OnboardingAnswer
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnboardingAnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnboardingAnswersTable,
      OnboardingAnswer,
      $$OnboardingAnswersTableFilterComposer,
      $$OnboardingAnswersTableOrderingComposer,
      $$OnboardingAnswersTableAnnotationComposer,
      $$OnboardingAnswersTableCreateCompanionBuilder,
      $$OnboardingAnswersTableUpdateCompanionBuilder,
      (
        OnboardingAnswer,
        BaseReferences<
          _$AppDatabase,
          $OnboardingAnswersTable,
          OnboardingAnswer
        >,
      ),
      OnboardingAnswer,
      PrefetchHooks Function()
    >;
typedef $$DiscoveriesFoundTableCreateCompanionBuilder =
    DiscoveriesFoundCompanion Function({
      required String discoveryKey,
      required int foundAt,
      Value<int> rowid,
    });
typedef $$DiscoveriesFoundTableUpdateCompanionBuilder =
    DiscoveriesFoundCompanion Function({
      Value<String> discoveryKey,
      Value<int> foundAt,
      Value<int> rowid,
    });

class $$DiscoveriesFoundTableFilterComposer
    extends Composer<_$AppDatabase, $DiscoveriesFoundTable> {
  $$DiscoveriesFoundTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get discoveryKey => $composableBuilder(
    column: $table.discoveryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get foundAt => $composableBuilder(
    column: $table.foundAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscoveriesFoundTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscoveriesFoundTable> {
  $$DiscoveriesFoundTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get discoveryKey => $composableBuilder(
    column: $table.discoveryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get foundAt => $composableBuilder(
    column: $table.foundAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscoveriesFoundTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscoveriesFoundTable> {
  $$DiscoveriesFoundTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get discoveryKey => $composableBuilder(
    column: $table.discoveryKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get foundAt =>
      $composableBuilder(column: $table.foundAt, builder: (column) => column);
}

class $$DiscoveriesFoundTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscoveriesFoundTable,
          DiscoveriesFoundData,
          $$DiscoveriesFoundTableFilterComposer,
          $$DiscoveriesFoundTableOrderingComposer,
          $$DiscoveriesFoundTableAnnotationComposer,
          $$DiscoveriesFoundTableCreateCompanionBuilder,
          $$DiscoveriesFoundTableUpdateCompanionBuilder,
          (
            DiscoveriesFoundData,
            BaseReferences<
              _$AppDatabase,
              $DiscoveriesFoundTable,
              DiscoveriesFoundData
            >,
          ),
          DiscoveriesFoundData,
          PrefetchHooks Function()
        > {
  $$DiscoveriesFoundTableTableManager(
    _$AppDatabase db,
    $DiscoveriesFoundTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveriesFoundTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscoveriesFoundTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscoveriesFoundTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> discoveryKey = const Value.absent(),
                Value<int> foundAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiscoveriesFoundCompanion(
                discoveryKey: discoveryKey,
                foundAt: foundAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String discoveryKey,
                required int foundAt,
                Value<int> rowid = const Value.absent(),
              }) => DiscoveriesFoundCompanion.insert(
                discoveryKey: discoveryKey,
                foundAt: foundAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiscoveriesFoundTable, DiscoveriesFoundData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $DiscoveriesFoundTable,
                    DiscoveriesFoundData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscoveriesFoundTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscoveriesFoundTable,
      DiscoveriesFoundData,
      $$DiscoveriesFoundTableFilterComposer,
      $$DiscoveriesFoundTableOrderingComposer,
      $$DiscoveriesFoundTableAnnotationComposer,
      $$DiscoveriesFoundTableCreateCompanionBuilder,
      $$DiscoveriesFoundTableUpdateCompanionBuilder,
      (
        DiscoveriesFoundData,
        BaseReferences<
          _$AppDatabase,
          $DiscoveriesFoundTable,
          DiscoveriesFoundData
        >,
      ),
      DiscoveriesFoundData,
      PrefetchHooks Function()
    >;
typedef $$QuestProgressTableCreateCompanionBuilder =
    QuestProgressCompanion Function({
      required String questKey,
      Value<int?> claimedAt,
      Value<int> rowid,
    });
typedef $$QuestProgressTableUpdateCompanionBuilder =
    QuestProgressCompanion Function({
      Value<String> questKey,
      Value<int?> claimedAt,
      Value<int> rowid,
    });

class $$QuestProgressTableFilterComposer
    extends Composer<_$AppDatabase, $QuestProgressTable> {
  $$QuestProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questKey => $composableBuilder(
    column: $table.questKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestProgressTable> {
  $$QuestProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questKey => $composableBuilder(
    column: $table.questKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestProgressTable> {
  $$QuestProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questKey =>
      $composableBuilder(column: $table.questKey, builder: (column) => column);

  GeneratedColumn<int> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);
}

class $$QuestProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestProgressTable,
          QuestProgressData,
          $$QuestProgressTableFilterComposer,
          $$QuestProgressTableOrderingComposer,
          $$QuestProgressTableAnnotationComposer,
          $$QuestProgressTableCreateCompanionBuilder,
          $$QuestProgressTableUpdateCompanionBuilder,
          (
            QuestProgressData,
            BaseReferences<
              _$AppDatabase,
              $QuestProgressTable,
              QuestProgressData
            >,
          ),
          QuestProgressData,
          PrefetchHooks Function()
        > {
  $$QuestProgressTableTableManager(_$AppDatabase db, $QuestProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> questKey = const Value.absent(),
                Value<int?> claimedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestProgressCompanion(
                questKey: questKey,
                claimedAt: claimedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String questKey,
                Value<int?> claimedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestProgressCompanion.insert(
                questKey: questKey,
                claimedAt: claimedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestProgressTable, QuestProgressData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $QuestProgressTable,
                    QuestProgressData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestProgressTable,
      QuestProgressData,
      $$QuestProgressTableFilterComposer,
      $$QuestProgressTableOrderingComposer,
      $$QuestProgressTableAnnotationComposer,
      $$QuestProgressTableCreateCompanionBuilder,
      $$QuestProgressTableUpdateCompanionBuilder,
      (
        QuestProgressData,
        BaseReferences<_$AppDatabase, $QuestProgressTable, QuestProgressData>,
      ),
      QuestProgressData,
      PrefetchHooks Function()
    >;
typedef $$QuestDailyStateTableCreateCompanionBuilder =
    QuestDailyStateCompanion Function({
      required String localDay,
      required String questKeys,
      Value<String> claimed,
      Value<String?> reflectionAnswer,
      Value<int> rowid,
    });
typedef $$QuestDailyStateTableUpdateCompanionBuilder =
    QuestDailyStateCompanion Function({
      Value<String> localDay,
      Value<String> questKeys,
      Value<String> claimed,
      Value<String?> reflectionAnswer,
      Value<int> rowid,
    });

class $$QuestDailyStateTableFilterComposer
    extends Composer<_$AppDatabase, $QuestDailyStateTable> {
  $$QuestDailyStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questKeys => $composableBuilder(
    column: $table.questKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get claimed => $composableBuilder(
    column: $table.claimed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reflectionAnswer => $composableBuilder(
    column: $table.reflectionAnswer,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuestDailyStateTableOrderingComposer
    extends Composer<_$AppDatabase, $QuestDailyStateTable> {
  $$QuestDailyStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questKeys => $composableBuilder(
    column: $table.questKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get claimed => $composableBuilder(
    column: $table.claimed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reflectionAnswer => $composableBuilder(
    column: $table.reflectionAnswer,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuestDailyStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuestDailyStateTable> {
  $$QuestDailyStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<String> get questKeys =>
      $composableBuilder(column: $table.questKeys, builder: (column) => column);

  GeneratedColumn<String> get claimed =>
      $composableBuilder(column: $table.claimed, builder: (column) => column);

  GeneratedColumn<String> get reflectionAnswer => $composableBuilder(
    column: $table.reflectionAnswer,
    builder: (column) => column,
  );
}

class $$QuestDailyStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuestDailyStateTable,
          QuestDailyStateData,
          $$QuestDailyStateTableFilterComposer,
          $$QuestDailyStateTableOrderingComposer,
          $$QuestDailyStateTableAnnotationComposer,
          $$QuestDailyStateTableCreateCompanionBuilder,
          $$QuestDailyStateTableUpdateCompanionBuilder,
          (
            QuestDailyStateData,
            BaseReferences<
              _$AppDatabase,
              $QuestDailyStateTable,
              QuestDailyStateData
            >,
          ),
          QuestDailyStateData,
          PrefetchHooks Function()
        > {
  $$QuestDailyStateTableTableManager(
    _$AppDatabase db,
    $QuestDailyStateTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuestDailyStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuestDailyStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuestDailyStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localDay = const Value.absent(),
                Value<String> questKeys = const Value.absent(),
                Value<String> claimed = const Value.absent(),
                Value<String?> reflectionAnswer = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestDailyStateCompanion(
                localDay: localDay,
                questKeys: questKeys,
                claimed: claimed,
                reflectionAnswer: reflectionAnswer,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localDay,
                required String questKeys,
                Value<String> claimed = const Value.absent(),
                Value<String?> reflectionAnswer = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuestDailyStateCompanion.insert(
                localDay: localDay,
                questKeys: questKeys,
                claimed: claimed,
                reflectionAnswer: reflectionAnswer,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuestDailyStateTable, QuestDailyStateData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $QuestDailyStateTable,
                    QuestDailyStateData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuestDailyStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuestDailyStateTable,
      QuestDailyStateData,
      $$QuestDailyStateTableFilterComposer,
      $$QuestDailyStateTableOrderingComposer,
      $$QuestDailyStateTableAnnotationComposer,
      $$QuestDailyStateTableCreateCompanionBuilder,
      $$QuestDailyStateTableUpdateCompanionBuilder,
      (
        QuestDailyStateData,
        BaseReferences<
          _$AppDatabase,
          $QuestDailyStateTable,
          QuestDailyStateData
        >,
      ),
      QuestDailyStateData,
      PrefetchHooks Function()
    >;
typedef $$ShopRotationTableCreateCompanionBuilder =
    ShopRotationCompanion Function({
      required String localDay,
      required String shop,
      Value<int> refreshCount,
      required String itemKeys,
      Value<int> rowid,
    });
typedef $$ShopRotationTableUpdateCompanionBuilder =
    ShopRotationCompanion Function({
      Value<String> localDay,
      Value<String> shop,
      Value<int> refreshCount,
      Value<String> itemKeys,
      Value<int> rowid,
    });

class $$ShopRotationTableFilterComposer
    extends Composer<_$AppDatabase, $ShopRotationTable> {
  $$ShopRotationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shop => $composableBuilder(
    column: $table.shop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refreshCount => $composableBuilder(
    column: $table.refreshCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKeys => $composableBuilder(
    column: $table.itemKeys,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShopRotationTableOrderingComposer
    extends Composer<_$AppDatabase, $ShopRotationTable> {
  $$ShopRotationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shop => $composableBuilder(
    column: $table.shop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refreshCount => $composableBuilder(
    column: $table.refreshCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKeys => $composableBuilder(
    column: $table.itemKeys,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShopRotationTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShopRotationTable> {
  $$ShopRotationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<String> get shop =>
      $composableBuilder(column: $table.shop, builder: (column) => column);

  GeneratedColumn<int> get refreshCount => $composableBuilder(
    column: $table.refreshCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemKeys =>
      $composableBuilder(column: $table.itemKeys, builder: (column) => column);
}

class $$ShopRotationTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShopRotationTable,
          ShopRotationData,
          $$ShopRotationTableFilterComposer,
          $$ShopRotationTableOrderingComposer,
          $$ShopRotationTableAnnotationComposer,
          $$ShopRotationTableCreateCompanionBuilder,
          $$ShopRotationTableUpdateCompanionBuilder,
          (
            ShopRotationData,
            BaseReferences<_$AppDatabase, $ShopRotationTable, ShopRotationData>,
          ),
          ShopRotationData,
          PrefetchHooks Function()
        > {
  $$ShopRotationTableTableManager(_$AppDatabase db, $ShopRotationTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShopRotationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShopRotationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShopRotationTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localDay = const Value.absent(),
                Value<String> shop = const Value.absent(),
                Value<int> refreshCount = const Value.absent(),
                Value<String> itemKeys = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShopRotationCompanion(
                localDay: localDay,
                shop: shop,
                refreshCount: refreshCount,
                itemKeys: itemKeys,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localDay,
                required String shop,
                Value<int> refreshCount = const Value.absent(),
                required String itemKeys,
                Value<int> rowid = const Value.absent(),
              }) => ShopRotationCompanion.insert(
                localDay: localDay,
                shop: shop,
                refreshCount: refreshCount,
                itemKeys: itemKeys,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShopRotationTable, ShopRotationData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ShopRotationTable,
                    ShopRotationData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShopRotationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShopRotationTable,
      ShopRotationData,
      $$ShopRotationTableFilterComposer,
      $$ShopRotationTableOrderingComposer,
      $$ShopRotationTableAnnotationComposer,
      $$ShopRotationTableCreateCompanionBuilder,
      $$ShopRotationTableUpdateCompanionBuilder,
      (
        ShopRotationData,
        BaseReferences<_$AppDatabase, $ShopRotationTable, ShopRotationData>,
      ),
      ShopRotationData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$HabitLogsTableTableManager get habitLogs =>
      $$HabitLogsTableTableManager(_db, _db.habitLogs);
  $$CheckinsTableTableManager get checkins =>
      $$CheckinsTableTableManager(_db, _db.checkins);
  $$ExerciseSessionsTableTableManager get exerciseSessions =>
      $$ExerciseSessionsTableTableManager(_db, _db.exerciseSessions);
  $$WalletTableTableManager get wallet =>
      $$WalletTableTableManager(_db, _db.wallet);
  $$WalletLedgerTableTableManager get walletLedger =>
      $$WalletLedgerTableTableManager(_db, _db.walletLedger);
  $$AdventuresTableTableManager get adventures =>
      $$AdventuresTableTableManager(_db, _db.adventures);
  $$InventoryTableTableManager get inventory =>
      $$InventoryTableTableManager(_db, _db.inventory);
  $$StreakStateTableTableManager get streakState =>
      $$StreakStateTableTableManager(_db, _db.streakState);
  $$SafetyFlagsTableTableManager get safetyFlags =>
      $$SafetyFlagsTableTableManager(_db, _db.safetyFlags);
  $$NotificationLogTableTableManager get notificationLog =>
      $$NotificationLogTableTableManager(_db, _db.notificationLog);
  $$EntitlementCacheTableTableManager get entitlementCache =>
      $$EntitlementCacheTableTableManager(_db, _db.entitlementCache);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$AnalyticsQueueTableTableManager get analyticsQueue =>
      $$AnalyticsQueueTableTableManager(_db, _db.analyticsQueue);
  $$ContentCacheTableTableManager get contentCache =>
      $$ContentCacheTableTableManager(_db, _db.contentCache);
  $$SupportMessagesCacheTableTableManager get supportMessagesCache =>
      $$SupportMessagesCacheTableTableManager(_db, _db.supportMessagesCache);
  $$OnboardingAnswersTableTableManager get onboardingAnswers =>
      $$OnboardingAnswersTableTableManager(_db, _db.onboardingAnswers);
  $$DiscoveriesFoundTableTableManager get discoveriesFound =>
      $$DiscoveriesFoundTableTableManager(_db, _db.discoveriesFound);
  $$QuestProgressTableTableManager get questProgress =>
      $$QuestProgressTableTableManager(_db, _db.questProgress);
  $$QuestDailyStateTableTableManager get questDailyState =>
      $$QuestDailyStateTableTableManager(_db, _db.questDailyState);
  $$ShopRotationTableTableManager get shopRotation =>
      $$ShopRotationTableTableManager(_db, _db.shopRotation);
}
