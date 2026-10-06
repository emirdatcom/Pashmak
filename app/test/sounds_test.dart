import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pashmak_app/core/time/clock.dart';
import 'package:pashmak_app/features/sounds/domain/sound_mixer.dart';
import 'package:pashmak_app/features/sounds/domain/sound_synth.dart';

class _FakeChannel implements SoundChannel {
  static final live = <_FakeChannel>[];
  double volume = 0;
  bool playing = false;
  @override
  Future<void> playLoop(Uint8List wav, double v) async {
    playing = true;
    volume = v;
    live.add(this);
  }

  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> dispose() async {
    playing = false;
    live.remove(this);
  }
}

void main() {
  group('synth', () {
    for (final layer in SoundLayer.values) {
      test('${layer.name}: audible, finite, peak-normalized and seamless', () {
        final s = synthLoop(layer, seconds: 3, rate: 8000);
        expect(s.length, 3 * 8000);
        var sum = 0.0, peak = 0.0;
        for (final v in s) {
          expect(v.isFinite, isTrue);
          sum += v * v;
          peak = math.max(peak, v.abs());
        }
        expect(math.sqrt(sum / s.length), greaterThan(0.02), reason: 'not silent');
        expect(peak, closeTo(0.8, 1e-3));
        // the jump from the last sample back to the first is no bigger than ordinary sample-to-sample steps
        var maxStep = 0.0;
        for (var i = 1; i < s.length; i++) {
          maxStep = math.max(maxStep, (s[i] - s[i - 1]).abs());
        }
        expect((s.first - s.last).abs(), lessThanOrEqualTo(maxStep + 1e-6));
      });
    }
    test('wav header and determinism', () {
      final a = synthWav(SoundLayer.rain, seconds: 1, rate: 8000);
      expect(String.fromCharCodes(a.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(a.sublist(8, 12)), 'WAVE');
      expect(a.length, 44 + 8000 * 2);
      expect(synthWav(SoundLayer.rain, seconds: 1, rate: 8000), a, reason: 'same seed, same bytes');
    });
  });

  group('mixer', () {
    setUp(_FakeChannel.live.clear);
    SoundMixer mixer() => SoundMixer(_FakeChannel.new, FakeClock(DateTime(2026, 10, 6, 9)), render: (l) async => Uint8List(44));

    test('preset plays its layers; toggling a layer off stops only that one; pause stops all', () async {
      final m = mixer();
      await m.applyPreset(SoundPreset.all.first);
      expect(m.playing, isTrue);
      expect(_FakeChannel.live, hasLength(SoundPreset.all.first.layers.length));
      final first = SoundPreset.all.first.layers.keys.first;
      await m.toggle(first);
      expect(_FakeChannel.live, hasLength(SoundPreset.all.first.layers.length - 1));
      await m.pause();
      expect(_FakeChannel.live, isEmpty);
      expect(m.volumes, isNotEmpty, reason: 'the mix stays selected');
    });

    test('volume is clamped and reaches the channel', () async {
      final m = mixer();
      await m.toggle(SoundLayer.rain);
      await m.play();
      await m.setVolume(SoundLayer.rain, 1.7);
      expect(m.volumes[SoundLayer.rain], 1.0);
      expect(_FakeChannel.live.single.volume, 1.0);
    });

    test('removing the last layer stops playback', () async {
      final m = mixer();
      await m.toggle(SoundLayer.waves);
      await m.play();
      await m.toggle(SoundLayer.waves);
      expect(m.playing, isFalse);
    });

    test('sleep timer reports the time left and can be cancelled', () {
      final m = mixer();
      m.setSleepTimer(const Duration(minutes: 15));
      expect(m.sleepLeft, const Duration(minutes: 15));
      m.setSleepTimer(null);
      expect(m.sleepLeft, isNull);
      m.dispose();
    });
  });
}
