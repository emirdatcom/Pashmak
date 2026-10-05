const _fa = '۰۱۲۳۴۵۶۷۸۹';
const _ar = '٠١٢٣٤٥٦٧٨٩';

/// Latin digits → Persian digits. Display layer only.
String toPersianDigits(Object? input) {
  final s = '$input';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = '0123456789'.indexOf(c);
    b.write(i >= 0 ? _fa[i] : c);
  }
  return b.toString();
}

/// Persian/Arabic-Indic digits → Latin. Use on user input before parsing.
String normalizeDigits(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    final c = String.fromCharCode(r);
    var i = _fa.indexOf(c);
    if (i < 0) i = _ar.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

/// Normalizes Arabic ي/ك to Persian ی/ک and drops ZWNJ/tatweel for matching.
String normalizePersianText(String s) => s
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('ـ', '')
    .replaceAll('‌', ' ');
