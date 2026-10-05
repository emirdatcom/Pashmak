import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;

/// docs/30 §11: every released schema version must migrate to the current one without data loss.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 → v3 (through the v2 support chat cache) keeps existing data', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.into(old.appMeta).insert(const RawValuesInsertable({'key': Variable('cat_name'), 'value': Variable('Pashmak')}));
    await old.into(old.habits).insert(const RawValuesInsertable({
      'id': Variable('h1'),
      'template_key': Variable('water'),
      'icon': Variable('water_drop'),
      'schedule_type': Variable('daily'),
      'weekdays_mask': Variable(127),
      'target_per_day': Variable(1),
      'sort_order': Variable(0),
      'is_locked': Variable(false),
      'created_at': Variable(1),
      'updated_at': Variable(1),
    }));
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    expect(await db.meta('cat_name'), 'Pashmak');
    expect((await db.select(db.habits).get()).single.id, 'h1');
    expect(await db.select(db.supportMessagesCache).get(), isEmpty);
    await db.close();
  });

  test('v2 → v3 maps legacy templates to goal keys and adds the new tables', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    for (final k in ['water', 'medicine']) {
      await old.into(old.habits).insert(RawValuesInsertable({
        'id': Variable('h_$k'),
        'template_key': Variable(k),
        'icon': const Variable('check'),
        'schedule_type': const Variable('daily'),
        'weekdays_mask': const Variable(127),
        'target_per_day': const Variable(1),
        'sort_order': const Variable(0),
        'is_locked': const Variable(false),
        'created_at': const Variable(1),
        'updated_at': const Variable(1),
      }));
    }
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final rows = {for (final h in await db.select(db.habits).get()) h.id: h};
    expect(rows['h_water']!.goalKey, 'food_water_glass');
    expect(rows['h_water']!.timeOfDay, 'any');
    expect(rows['h_water']!.repeatType, 'daily');
    expect(rows['h_medicine']!.goalKey, 'medicine', reason: 'no library equivalent: keeps the legacy key');
    expect(await db.select(db.discoveriesFound).get(), isEmpty);
    await db.close();
  });
}
