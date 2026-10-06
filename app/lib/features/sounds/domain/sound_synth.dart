import 'dart:math' as math;
import 'dart:typed_data';

/// The ambient layers the mixer can play. Every one is synthesized on the device (no audio files to ship or
/// download), deterministic for a seed, and rendered as a seamless loop.
enum SoundLayer { rain, waves, wind, fire, stream, night, birds, purr, white, pink, brown }

/// Renders [layer] as a mono 16-bit PCM WAV loop of [seconds] at [rate] Hz. Pure and deterministic.
Uint8List synthWav(SoundLayer layer, {int seconds = 12, int rate = 22050, int seed = 7}) =>
    pcmToWav(synthLoop(layer, seconds: seconds, rate: rate, seed: seed), rate);

/// The loop as samples in -1..1. One extra second is rendered and cross-faded into the start so the end flows
/// into the beginning without a click.
Float32List synthLoop(SoundLayer layer, {int seconds = 12, int rate = 22050, int seed = 7}) {
  final n = seconds * rate;
  final fade = rate; // 1 s
  final raw = _render(layer, n + fade, rate, math.Random(seed));
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    out[i] = raw[i];
  }
  for (var i = 0; i < fade; i++) {
    final w = i / fade;
    out[i] = raw[i] * w + raw[n + i] * (1 - w);
  }
  var peak = 1e-9;
  for (final v in out) {
    peak = math.max(peak, v.abs());
  }
  final gain = 0.8 / peak;
  for (var i = 0; i < n; i++) {
    out[i] *= gain;
  }
  return out;
}

Float32List _render(SoundLayer layer, int n, int rate, math.Random r) {
  final b = Float32List(n);
  double white() => r.nextDouble() * 2 - 1;
  switch (layer) {
    case SoundLayer.white:
      for (var i = 0; i < n; i++) {
        b[i] = white() * 0.5;
      }
    case SoundLayer.pink:
      _pink(b, white);
    case SoundLayer.brown:
      _brown(b, white);
    case SoundLayer.rain:
      // hiss of falling rain (pink, high-passed) + many small drops
      final p = Float32List(n);
      _pink(p, white);
      var lp = 0.0;
      for (var i = 0; i < n; i++) {
        lp += 0.08 * (p[i] - lp);
        b[i] = (p[i] - lp) * 0.6;
      }
      _bursts(b, r, rate, perSecond: 45, minMs: 2, maxMs: 9, amp: 0.35, white: white);
    case SoundLayer.waves:
      final br = Float32List(n);
      _brown(br, white);
      final p = Float32List(n);
      _pink(p, white);
      const period = 8.0;
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        final swell = math.pow((1 - math.cos(2 * math.pi * t / period)) / 2, 2).toDouble();
        b[i] = br[i] * (0.25 + 0.75 * swell) + p[i] * 0.25 * swell;
      }
    case SoundLayer.wind:
      final p = Float32List(n);
      _pink(p, white);
      var lp = 0.0;
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        final gust = 0.5 + 0.5 * math.sin(2 * math.pi * t / 6.0) * math.sin(2 * math.pi * t / 2.3 + 1);
        lp += (0.01 + 0.05 * gust) * (p[i] - lp);
        b[i] = lp * (0.4 + 0.6 * gust) * 3;
      }
    case SoundLayer.fire:
      final br = Float32List(n);
      _brown(br, white);
      for (var i = 0; i < n; i++) {
        b[i] = br[i] * 0.5;
      }
      _bursts(b, r, rate, perSecond: 9, minMs: 3, maxMs: 18, amp: 0.9, white: white);
    case SoundLayer.stream:
      var lp = 0.0, hp = 0.0;
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        final gurgle = 0.6 + 0.4 * (math.sin(2 * math.pi * 3.1 * t) * math.sin(2 * math.pi * 5.3 * t + 2) * math.sin(2 * math.pi * 0.7 * t));
        lp += 0.35 * (white() - lp);
        hp += 0.02 * (lp - hp);
        b[i] = (lp - hp) * gurgle;
      }
    case SoundLayer.night:
      final br = Float32List(n);
      _brown(br, white);
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        // crickets: three 30 ms pulses of a 4.4 kHz tone every 0.8 s
        final inCycle = t % 0.8;
        final pulse = inCycle < 0.21 && (inCycle % 0.07) < 0.03;
        b[i] = br[i] * 0.3 + (pulse ? 0.25 * math.sin(2 * math.pi * 4400 * t) : 0);
      }
    case SoundLayer.birds:
      final p = Float32List(n);
      _pink(p, white);
      for (var i = 0; i < n; i++) {
        b[i] = p[i] * 0.05;
      }
      var t = 0.4;
      final total = n / rate;
      while (t < total - 0.5) {
        final notes = 2 + r.nextInt(3);
        final f0 = 2400 + r.nextDouble() * 1200;
        for (var k = 0; k < notes; k++) {
          _chirp(b, rate, start: t + k * 0.16, dur: 0.11, f0: f0, f1: f0 + 900 + r.nextDouble() * 600, amp: 0.4);
        }
        t += 1.2 + r.nextDouble() * 1.6;
      }
    case SoundLayer.purr:
      // a low rumble pulsing about 25 times a second, louder on the "breath in" of a ~2 s cycle
      final br = Float32List(n);
      _brown(br, white);
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * 25 * t);
        final breath = 0.55 + 0.45 * math.sin(2 * math.pi * t / 2.0);
        b[i] = br[i] * pulse * breath;
      }
  }
  return b;
}

/// Paul Kellet's economy pink filter over white noise.
void _pink(Float32List b, double Function() white) {
  var b0 = 0.0, b1 = 0.0, b2 = 0.0;
  for (var i = 0; i < b.length; i++) {
    final w = white();
    b0 = 0.99765 * b0 + w * 0.0990460;
    b1 = 0.96300 * b1 + w * 0.2965164;
    b2 = 0.57000 * b2 + w * 1.0526913;
    b[i] = (b0 + b1 + b2 + w * 0.1848) * 0.18;
  }
}

/// Leaky integrated white noise (deep rumble).
void _brown(Float32List b, double Function() white) {
  var last = 0.0;
  for (var i = 0; i < b.length; i++) {
    last = (last + 0.02 * white()) / 1.02;
    b[i] = last * 3.5;
  }
}

/// Short decaying noise bursts (drops, crackles) added onto [b].
void _bursts(Float32List b, math.Random r, int rate, {required double perSecond, required int minMs, required int maxMs, required double amp, required double Function() white}) {
  final count = (b.length / rate * perSecond).round();
  for (var k = 0; k < count; k++) {
    final start = r.nextInt(b.length);
    final len = ((minMs + r.nextInt(maxMs - minMs + 1)) * rate / 1000).round();
    final a = amp * (0.3 + 0.7 * r.nextDouble());
    for (var j = 0; j < len && start + j < b.length; j++) {
      b[start + j] += white() * a * math.exp(-5.0 * j / len);
    }
  }
}

/// A rising sine chirp with a soft bell envelope.
void _chirp(Float32List b, int rate, {required double start, required double dur, required double f0, required double f1, required double amp}) {
  final s = (start * rate).round();
  final len = (dur * rate).round();
  var phase = 0.0;
  for (var j = 0; j < len && s + j < b.length; j++) {
    final x = j / len;
    phase += 2 * math.pi * (f0 + (f1 - f0) * x) / rate;
    b[s + j] += amp * math.sin(math.pi * x) * math.sin(phase);
  }
}

/// Wraps samples (-1..1) in a minimal WAV container (PCM 16-bit mono).
Uint8List pcmToWav(Float32List samples, int rate) {
  final data = samples.length * 2;
  final out = ByteData(44 + data);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  out.setUint32(4, 36 + data, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 1, Endian.little); // mono
  out.setUint32(24, rate, Endian.little);
  out.setUint32(28, rate * 2, Endian.little);
  out.setUint16(32, 2, Endian.little);
  out.setUint16(34, 16, Endian.little);
  str(36, 'data');
  out.setUint32(40, data, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    out.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return out.buffer.asUint8List();
}
