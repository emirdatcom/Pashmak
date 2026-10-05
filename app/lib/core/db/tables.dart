// All local tables of docs/30 §3. Names and fields must match the doc; change the doc first.
import 'package:drift/drift.dart';

class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class UserSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get templateKey => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get icon => text().withDefault(const Constant('check'))();
  TextColumn get scheduleType => text().withDefault(const Constant('daily'))();
  IntColumn get weekdaysMask => integer().withDefault(const Constant(127))();
  IntColumn get targetPerDay => integer().withDefault(const Constant(1))();
  IntColumn get reminderMinutes => integer().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  IntColumn get archivedAt => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get localDay => text()();
  IntColumn get count => integer().withDefault(const Constant(1))();
  IntColumn get completedAt => integer()();
  TextColumn get source => text().withDefault(const Constant('app'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, localDay},
      ];
}

class Checkins extends Table {
  TextColumn get id => text()();
  TextColumn get localDay => text()();
  IntColumn get moodLevel => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get tags => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('app'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class ExerciseSessions extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseKey => text()();
  IntColumn get startedAt => integer()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get durationS => integer().withDefault(const Constant(0))();
  TextColumn get localDay => text()();
  TextColumn get journalText => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Wallet extends Table {
  IntColumn get id => integer()();
  IntColumn get energy => integer().withDefault(const Constant(0))();
  IntColumn get coins => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class WalletLedger extends Table {
  TextColumn get id => text()();
  TextColumn get currency => text()(); // energy | coins
  IntColumn get delta => integer()();
  TextColumn get reason => text()();
  TextColumn get refId => text()();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
        {reason, refId},
      ];
}

class Adventures extends Table {
  TextColumn get id => text()();
  TextColumn get locationKey => text()();
  IntColumn get energyCost => integer()();
  IntColumn get startedAt => integer()();
  IntColumn get endsAt => integer()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get rewardCoins => integer().withDefault(const Constant(0))();
  TextColumn get rewardItemKey => text().nullable()();
  TextColumn get storyKey => text().nullable()();
  IntColumn get claimedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Inventory extends Table {
  TextColumn get itemKey => text()();
  IntColumn get acquiredAt => integer()();
  TextColumn get source => text()(); // shop | adventure | iap | seasonal
  BoolColumn get equipped => boolean().withDefault(const Constant(false))();
  TextColumn get slot => text()();
  @override
  Set<Column> get primaryKey => {itemKey};
}

class StreakState extends Table {
  IntColumn get id => integer()();
  IntColumn get current => integer().withDefault(const Constant(0))();
  IntColumn get longest => integer().withDefault(const Constant(0))();
  TextColumn get lastActiveDay => text().nullable()();
  IntColumn get freezesLeft => integer().withDefault(const Constant(1))();
  TextColumn get freezeMonth => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Never sent anywhere (docs/80 §1).
class SafetyFlags extends Table {
  TextColumn get id => text()();
  TextColumn get localDay => text()();
  TextColumn get kind => text()(); // low_mood_streak | keyword
  IntColumn get shownAt => integer().nullable()();
  IntColumn get dismissedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class NotificationLog extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  IntColumn get scheduledFor => integer()();
  IntColumn get deliveredAt => integer().nullable()();
  IntColumn get openedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class EntitlementCache extends Table {
  IntColumn get id => integer()();
  TextColumn get stateJson => text()();
  TextColumn get signature => text()();
  TextColumn get kid => text()();
  IntColumn get fetchedAt => integer()();
  IntColumn get pendingVerificationUntil => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // trial_start | purchase_verify | purchase_restore | events_flush
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class AnalyticsQueue extends Table {
  TextColumn get id => text()(); // = event_id
  TextColumn get name => text()();
  TextColumn get props => text()();
  IntColumn get ts => integer()();
  TextColumn get sessionId => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class ContentCache extends Table {
  TextColumn get packKey => text()();
  IntColumn get version => integer()();
  TextColumn get sha256 => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {packKey};
}
