import 'dart:convert';

import '../l10n/digits.dart';

/// Resolves user-facing text from content packs (docs/40 §3).
///
/// Order: downloaded pack → bundled pack → (debug: the key itself / release: empty string).
/// List values are variants picked deterministically per key and day, so the same screen shows the
/// same sentence all day but varies across days.
class CopyResolver {
  CopyResolver({
    required Map<String, dynamic> bundled,
    Map<String, dynamic> downloaded = const {},
    required this.appName,
    required this.defaultCatName,
    this.catName,
    required this.today,
    this.debug = false,
    this.onMissing,
  })  : _bundled = bundled,
        _downloaded = downloaded;

  final Map<String, dynamic> _bundled;
  final Map<String, dynamic> _downloaded;
  final String appName;
  final String defaultCatName;
  final String? catName;
  final String Function() today; // LocalDay.value
  final bool debug;
  final void Function(String key)? onMissing;

  bool has(String key) => _downloaded.containsKey(key) || _bundled.containsKey(key);

  /// Stable 32-bit FNV-1a hash (same on every platform, unlike String.hashCode).
  static int hash(String s) {
    var h = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  String t(String key, [Map<String, Object?> vars = const {}]) {
    final raw = _downloaded[key] ?? _bundled[key];
    if (raw == null) {
      onMissing?.call(key);
      return debug ? key : '';
    }
    String text;
    if (raw is List) {
      if (raw.isEmpty) return debug ? key : '';
      text = raw[hash('$key${today()}') % raw.length] as String;
    } else {
      text = raw as String;
    }
    return text.replaceAllMapped(RegExp(r'\{([A-Za-z_]+)\}'), (m) {
      final name = m[1]!;
      switch (name) {
        case 'APP_NAME':
          return appName;
        case 'CAT_NAME':
          return (catName != null && catName!.trim().isNotEmpty) ? catName! : defaultCatName;
      }
      final v = vars[name];
      if (v == null) return m[0]!;
      return v is num ? toPersianDigits(v) : '$v';
    });
  }
}
