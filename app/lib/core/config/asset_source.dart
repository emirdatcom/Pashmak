import 'package:flutter/services.dart' show rootBundle;

/// Where bundled JSON comes from (assets in the app, a map in tests).
abstract class AssetSource {
  Future<String> load(String path);
  Future<bool> exists(String path);
}

class BundleAssetSource implements AssetSource {
  const BundleAssetSource();
  @override
  Future<String> load(String path) => rootBundle.loadString(path);
  @override
  Future<bool> exists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class MapAssetSource implements AssetSource {
  MapAssetSource(this.files);
  final Map<String, String> files;
  @override
  Future<String> load(String path) async => files[path] ?? (throw StateError('missing asset $path'));
  @override
  Future<bool> exists(String path) async => files.containsKey(path);
}
