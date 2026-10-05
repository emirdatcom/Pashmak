/// Current snapshot format. Bump together with a new upgrader whenever the exported shape changes
/// (docs/30 §11: every schema_version has one JSON-to-JSON upgrade function).
const currentSnapshotSchema = 1;

typedef SnapshotUpgrader = Map<String, dynamic> Function(Map<String, dynamic> snapshot);

class SnapshotTooNew implements Exception {
  const SnapshotTooNew(this.version);
  final int version;
  @override
  String toString() => 'SnapshotTooNew($version)';
}

/// Applies `from → from+1 → … → current`. [chain] maps a version to the function producing the next one.
class SnapshotUpgraders {
  SnapshotUpgraders({Map<int, SnapshotUpgrader>? chain, this.current = currentSnapshotSchema}) : chain = chain ?? const {};

  final Map<int, SnapshotUpgrader> chain;
  final int current;

  Map<String, dynamic> upgrade(Map<String, dynamic> snapshot, int from) {
    if (from > current) throw SnapshotTooNew(from);
    var s = snapshot;
    for (var v = from; v < current; v++) {
      final up = chain[v];
      if (up == null) throw StateError('missing snapshot upgrader $v → ${v + 1}');
      s = up(s);
      s['schema_version'] = v + 1;
    }
    return s;
  }
}
