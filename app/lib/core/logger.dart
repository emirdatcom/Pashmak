import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'db/app_database.dart';

/// Local logger. Release builds only log warnings and errors, and the last 200 errors are kept in
/// app_meta for support. Never pass note text or mood values (docs/80 §1).
class AppLogger {
  AppLogger._();
  static const maxErrors = 200;
  static AppDatabase? _db;
  static final List<Map<String, Object?>> _errors = [];

  static void attach(AppDatabase db) => _db = db;

  static List<Map<String, Object?>> get recentErrors => List.unmodifiable(_errors);

  static void info(String message) {
    if (!kReleaseMode) dev.log(message, name: 'app');
  }

  static void warn(String message) => dev.log(message, name: 'app', level: 900);

  static void error(Object error, [StackTrace? stack, String? context]) {
    dev.log('${context ?? 'error'}: $error', name: 'app', level: 1000, stackTrace: stack);
    _errors.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'context': context,
      'error': '$error',
      'stack': stack?.toString().split('\n').take(8).join('\n'),
    });
    if (_errors.length > maxErrors) _errors.removeRange(0, _errors.length - maxErrors);
    final db = _db;
    if (db != null) {
      db.setMeta('error_log', jsonEncode(_errors)).catchError((_) {});
    }
  }

  static void reset() => _errors.clear();
}
