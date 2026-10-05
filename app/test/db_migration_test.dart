import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;

/// docs/30 §11: every released schema version must migrate to the current one without data loss.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 → v2 adds the support chat cache and keeps existing data', () async {
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
    await verifier.migrateAndValidate(db, 2);
    expect(await db.meta('cat_name'), 'Pashmak');
    expect((await db.select(db.habits).get()).single.id, 'h1');
    expect(await db.select(db.supportMessagesCache).get(), isEmpty);
    await db.close();
  });
}
