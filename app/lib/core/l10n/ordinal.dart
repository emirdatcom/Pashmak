import '../content/copy_resolver.dart';

/// "اول", "دوم", … from copy (`ordinal.1`…`ordinal.10`), then "۱۱ام" (`ordinal.many`).
String ordinalOf(CopyResolver copy, int n) => n >= 1 && n <= 10 ? copy.t('ordinal.$n') : copy.t('ordinal.many', {'n': n});
