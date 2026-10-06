import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../domain/sound_mixer.dart';

/// A [SoundChannel] on `audioplayers`: plays a WAV from memory in a loop, mixing with the other channels.
class AudioplayersChannel implements SoundChannel {
  final AudioPlayer _p = AudioPlayer();

  @override
  Future<void> playLoop(Uint8List wav, double volume) async {
    await _p.setAudioContext(AudioContext(
      android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none, usageType: AndroidUsageType.media, contentType: AndroidContentType.music),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {AVAudioSessionOptions.mixWithOthers}),
    ));
    await _p.setReleaseMode(ReleaseMode.loop);
    await _p.setVolume(volume);
    await _p.play(BytesSource(wav, mimeType: 'audio/wav'));
  }

  @override
  Future<void> setVolume(double volume) => _p.setVolume(volume);

  @override
  Future<void> stop() => _p.stop();

  @override
  Future<void> dispose() async {
    await _p.stop();
    await _p.dispose();
  }
}
