import 'package:flutter/services.dart';

/// Which cat renderer to use (docs/20 §9): the animated Rive cat only when the remote flag is on, the device
/// has enough RAM and the `.riv` asset is actually bundled; otherwise the always-available static renderer.
enum CatRendererKind { staticCat, rive }

const riveCatAsset = 'assets/cat/cat.riv';
const riveMinRamMb = 3072;

CatRendererKind selectCatRenderer({required bool flagEnabled, required int? ramMb, required bool assetBundled}) {
  if (!flagEnabled) return CatRendererKind.staticCat; // flag off ⇒ the Rive asset is never even looked at
  if (ramMb == null || ramMb < riveMinRamMb) return CatRendererKind.staticCat;
  return assetBundled ? CatRendererKind.rive : CatRendererKind.staticCat;
}

/// Device RAM in MB through the existing `app/device` channel (null when unknown, e.g. tests).
Future<int?> deviceRamMb() async {
  try {
    return await const MethodChannel('app/device').invokeMethod<int>('totalRamMb');
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

/// True only when the `.riv` file is part of the app bundle (art is not in the repo yet).
Future<bool> riveAssetBundled(AssetBundle bundle) async {
  try {
    await bundle.load(riveCatAsset);
    return true;
  } catch (_) {
    return false;
  }
}

/// Entry point for the app: loads nothing unless the flag is on.
Future<CatRendererKind> resolveCatRenderer({required bool flagEnabled, AssetBundle? bundle}) async {
  if (!flagEnabled) return CatRendererKind.staticCat;
  return selectCatRenderer(flagEnabled: true, ramMb: await deviceRamMb(), assetBundled: await riveAssetBundled(bundle ?? rootBundle));
}
