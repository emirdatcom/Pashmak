import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// Source of the hardware-ish id sent as `device_hash_raw` (server salts and hashes it).
abstract class DeviceIdSource {
  Future<String> rawDeviceId();
}

/// Reads ANDROID_ID through a tiny platform channel (see MainActivity.kt).
class AndroidDeviceIdSource implements DeviceIdSource {
  static const _channel = MethodChannel('app/device');
  @override
  Future<String> rawDeviceId() async => (await _channel.invokeMethod<String>('androidId')) ?? 'unknown';
}

class FixedDeviceIdSource implements DeviceIdSource {
  const FixedDeviceIdSource(this.id);
  final String id;
  @override
  Future<String> rawDeviceId() async => id;
}

/// `install_id` (UUIDv4, created on first run, kept in app_meta) plus the raw device id.
class DeviceIdentity {
  DeviceIdentity(this._db, this._source);
  final AppDatabase _db;
  final DeviceIdSource _source;

  Future<String> installId() async {
    final existing = await _db.meta('install_id');
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _db.setMeta('install_id', id);
    return id;
  }

  Future<String> deviceHashRaw() => _source.rawDeviceId();
}
