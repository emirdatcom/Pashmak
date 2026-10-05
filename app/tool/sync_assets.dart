// Copies config-data/ (config default + content packs) into app/assets/.
// Run from app/: dart run tool/sync_assets.dart   (CI fails if the copies are stale: add --check)
import 'dart:io';

void main(List<String> args) {
  final check = args.contains('--check');
  final src = Directory('../config-data');
  final pairs = <File, File>{
    File('${src.path}/config/default.json'): File('assets/config/default.json'),
  };
  for (final f in Directory('${src.path}/content').listSync().whereType<File>()) {
    if (f.path.endsWith('.json')) {
      pairs[f] = File('assets/content/${f.uri.pathSegments.last}');
    }
  }
  var stale = 0;
  pairs.forEach((from, to) {
    final data = from.readAsBytesSync();
    if (check) {
      if (!to.existsSync() || !_same(to.readAsBytesSync(), data)) {
        stderr.writeln('stale: ${to.path}');
        stale++;
      }
    } else {
      to.parent.createSync(recursive: true);
      to.writeAsBytesSync(data);
    }
  });
  if (check && stale > 0) exit(1);
  stdout.writeln(check ? 'assets up to date' : 'synced ${pairs.length} files');
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
