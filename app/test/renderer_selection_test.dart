
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/features/cat/renderer_selection.dart';

class _CountingBundle extends CachingAssetBundle {
  int loads = 0;
  @override
  Future<ByteData> load(String key) async {
    loads++;
    throw StateError('no such asset');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('selection table', () {
    CatRendererKind k(bool f, int? ram, bool asset) => selectCatRenderer(flagEnabled: f, ramMb: ram, assetBundled: asset);
    expect(k(false, 8000, true), CatRendererKind.staticCat);
    expect(k(true, 2048, true), CatRendererKind.staticCat, reason: 'weak device');
    expect(k(true, null, true), CatRendererKind.staticCat, reason: 'unknown RAM is treated as weak');
    expect(k(true, 4096, false), CatRendererKind.staticCat, reason: 'no art bundled');
    expect(k(true, 3072, true), CatRendererKind.rive);
  });

  test('flag off: no asset is loaded at all; flag on without art falls back to static', () async {
    final b = _CountingBundle();
    expect(await resolveCatRenderer(flagEnabled: false, bundle: b), CatRendererKind.staticCat);
    expect(b.loads, 0);
    expect(await resolveCatRenderer(flagEnabled: true, bundle: b), CatRendererKind.staticCat);
  });
}
