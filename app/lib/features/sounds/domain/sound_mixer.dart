import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/time/clock.dart';
import 'sound_synth.dart';

/// One playing channel (an audio player in the app, a fake in tests).
abstract class SoundChannel {
  Future<void> playLoop(Uint8List wav, double volume);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

typedef SoundChannelFactory = SoundChannel Function();

/// Layers in a mix and their volumes; free layers need no premium.
class SoundPreset {
  const SoundPreset(this.key, this.icon, this.layers, {this.premium = false});
  final String key;
  final String icon;
  final Map<SoundLayer, double> layers;
  final bool premium;

  static const all = [
    SoundPreset('rainy_night', 'nature/moon', {SoundLayer.rain: 0.8, SoundLayer.purr: 0.3}),
    SoundPreset('seaside', 'nature/landscape', {SoundLayer.waves: 0.9, SoundLayer.wind: 0.2}),
    SoundPreset('forest_morning', 'nature/sunrise', {SoundLayer.birds: 0.7, SoundLayer.stream: 0.5}, premium: true),
    SoundPreset('cozy_fire', 'calm/candle', {SoundLayer.fire: 0.8, SoundLayer.rain: 0.4}, premium: true),
    SoundPreset('summer_night', 'nature/moon', {SoundLayer.night: 0.7, SoundLayer.wind: 0.3}, premium: true),
    SoundPreset('cat_nap', 'animals/cat', {SoundLayer.purr: 0.9, SoundLayer.brown: 0.3}),
    SoundPreset('deep_focus', 'tech/headphones', {SoundLayer.pink: 0.6, SoundLayer.stream: 0.3}, premium: true),
  ];
}

/// Sticker and premium flag of every layer.
const soundLayerIcon = {
  SoundLayer.rain: 'nature/cloud',
  SoundLayer.waves: 'nature/landscape',
  SoundLayer.wind: 'misc/kite',
  SoundLayer.fire: 'calm/candle',
  SoundLayer.stream: 'food/water_glass',
  SoundLayer.night: 'nature/moon',
  SoundLayer.birds: 'animals/chick',
  SoundLayer.purr: 'animals/cat',
  SoundLayer.white: 'tech/headphones',
  SoundLayer.pink: 'tech/headphones',
  SoundLayer.brown: 'tech/headphones',
};
const freeSoundLayers = {SoundLayer.rain, SoundLayer.waves, SoundLayer.purr, SoundLayer.white};

/// The live mix: which layers play at which volume, start/stop, and a sleep timer that fades everything out.
/// Loops are rendered once (in a background isolate) and cached.
class SoundMixer extends ChangeNotifier {
  SoundMixer(this._newChannel, this._clock, {Future<Uint8List> Function(SoundLayer)? render}) : _render = render ?? _renderInIsolate;

  final SoundChannelFactory _newChannel;
  final Clock _clock;
  final Future<Uint8List> Function(SoundLayer) _render;
  final Map<SoundLayer, double> _volumes = {};
  final Map<SoundLayer, SoundChannel> _channels = {};
  final Map<SoundLayer, Uint8List> _cache = {};
  bool _playing = false;
  Timer? _sleep;
  DateTime? _sleepAt;

  static Future<Uint8List> _renderInIsolate(SoundLayer l) => compute(_synth, l);
  static Uint8List _synth(SoundLayer l) => synthWav(l);

  Map<SoundLayer, double> get volumes => Map.unmodifiable(_volumes);
  bool get playing => _playing;
  bool isOn(SoundLayer l) => _volumes.containsKey(l);

  /// Remaining sleep-timer time, or null.
  Duration? get sleepLeft {
    final at = _sleepAt;
    if (at == null) return null;
    final d = at.difference(_clock.now());
    return d.isNegative ? Duration.zero : d;
  }

  Future<void> toggle(SoundLayer l, {double volume = 0.7}) async {
    if (_volumes.containsKey(l)) {
      _volumes.remove(l);
      await _channels.remove(l)?.dispose();
    } else {
      _volumes[l] = volume;
      if (_playing) await _start(l);
    }
    if (_volumes.isEmpty) _playing = false;
    notifyListeners();
  }

  Future<void> setVolume(SoundLayer l, double v) async {
    if (!_volumes.containsKey(l)) return;
    _volumes[l] = v.clamp(0.0, 1.0);
    await _channels[l]?.setVolume(_volumes[l]!);
    notifyListeners();
  }

  /// Replaces the mix with [p] and plays it.
  Future<void> applyPreset(SoundPreset p) async {
    await _stopAll();
    _volumes
      ..clear()
      ..addAll(p.layers);
    await play();
  }

  Future<void> play() async {
    if (_volumes.isEmpty) return;
    _playing = true;
    notifyListeners();
    for (final l in _volumes.keys.toList()) {
      if (!_channels.containsKey(l)) await _start(l);
    }
  }

  Future<void> pause() async {
    _playing = false;
    await _stopAll();
    notifyListeners();
  }

  Future<void> _start(SoundLayer l) async {
    final wav = _cache[l] ??= await _render(l);
    if (!_playing || !_volumes.containsKey(l) || _channels.containsKey(l)) return;
    final ch = _newChannel();
    _channels[l] = ch;
    await ch.playLoop(wav, _volumes[l]!);
  }

  Future<void> _stopAll() async {
    for (final ch in _channels.values) {
      await ch.dispose();
    }
    _channels.clear();
  }

  /// Stops everything after [d] (with a 20 s fade); null cancels the timer.
  void setSleepTimer(Duration? d) {
    _sleep?.cancel();
    _sleepAt = d == null ? null : _clock.now().add(d);
    if (d != null) {
      _sleep = Timer(d, () async {
        const steps = 10;
        final start = Map.of(_volumes);
        for (var i = steps - 1; i >= 0; i--) {
          for (final e in start.entries) {
            await _channels[e.key]?.setVolume(e.value * i / steps);
          }
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        await pause();
        _volumes.addAll(start); // the mix stays selected for next time
        _sleepAt = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sleep?.cancel();
    unawaited(_stopAll());
    super.dispose();
  }
}
