import 'dart:convert';
import 'dart:typed_data';

/// Canonical JSON used to sign/verify EntitlementState (docs/10 §6.2). Must stay byte-identical to the
/// Go implementation (`entitlement.Canonicalize`):
///  1. object keys sorted by UTF-8 bytes at every level;
///  2. no whitespace;
///  3. strings escape only `"`, `\`, `\b \f \n \r \t` and other control characters (< 0x20) as `\u00xx`;
///     `/` and non-ASCII characters are written as-is;
///  4. integers without fraction/exponent; booleans and null as usual.
Uint8List canonicalJson(Object? value) {
  final b = StringBuffer();
  _write(b, value);
  return Uint8List.fromList(utf8.encode(b.toString()));
}

int _compareUtf8(String a, String b) {
  final x = utf8.encode(a), y = utf8.encode(b);
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
  }
  return x.length.compareTo(y.length);
}

void _write(StringBuffer b, Object? v) {
  switch (v) {
    case null:
      b.write('null');
    case bool():
      b.write(v ? 'true' : 'false');
    case int():
      b.write(v);
    case double():
      if (v == v.truncateToDouble() && v.abs() < 1e15) {
        b.write(v.toInt());
      } else {
        throw ArgumentError('non-integer numbers are not part of the signed contract: $v');
      }
    case String():
      _writeString(b, v);
    case List():
      b.write('[');
      for (var i = 0; i < v.length; i++) {
        if (i > 0) b.write(',');
        _write(b, v[i]);
      }
      b.write(']');
    case Map():
      final keys = v.keys.cast<String>().toList()..sort(_compareUtf8);
      b.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) b.write(',');
        _writeString(b, keys[i]);
        b.write(':');
        _write(b, v[keys[i]]);
      }
      b.write('}');
    default:
      throw ArgumentError('unsupported type ${v.runtimeType}');
  }
}

void _writeString(StringBuffer b, String s) {
  b.write('"');
  for (final r in s.runes) {
    switch (r) {
      case 0x22:
        b.write(r'\"');
      case 0x5c:
        b.write(r'\\');
      case 0x08:
        b.write(r'\b');
      case 0x0c:
        b.write(r'\f');
      case 0x0a:
        b.write(r'\n');
      case 0x0d:
        b.write(r'\r');
      case 0x09:
        b.write(r'\t');
      default:
        if (r < 0x20) {
          b.write('\\u${r.toRadixString(16).padLeft(4, '0')}');
        } else {
          b.writeCharCode(r);
        }
    }
  }
  b.write('"');
}
