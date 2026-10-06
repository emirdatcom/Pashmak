import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../home/presentation/home_screen.dart' show passGate;
import '../data/audioplayers_channel.dart';
import '../domain/sound_mixer.dart';
import '../domain/sound_synth.dart';

/// Kept alive app-wide so sounds keep playing while the user moves around the app.
final soundMixerProvider = Provider<SoundMixer>((ref) {
  final m = SoundMixer(AudioplayersChannel.new, ref.watch(clockProvider));
  ref.onDispose(m.dispose);
  return m;
});

/// Ambient sound mixer: presets, layers with volumes, play/pause and a sleep timer.
class SoundsScreen extends ConsumerStatefulWidget {
  const SoundsScreen({super.key});
  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(soundMixerProvider).sleepLeft != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<bool> _allowed(bool premiumOnly) async {
    if (!premiumOnly || ref.read(premiumProvider)) return true;
    await passGate(context, ref, 'premium_exercise');
    return ref.read(premiumProvider);
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final mixer = ref.watch(soundMixerProvider);
    final premium = ref.watch(premiumProvider);
    return ListenableBuilder(
      listenable: mixer,
      builder: (context, _) {
        final left = mixer.sleepLeft;
        return Scaffold(
          backgroundColor: DS.bgBagScene,
          appBar: AppBar(title: Text(copy.t('sounds.title')), backgroundColor: DS.bgBagScene, foregroundColor: DS.onDark),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            Text(copy.t('sounds.subtitle'), style: const TextStyle(color: DS.onDark, fontSize: 15)),
            const SizedBox(height: 16),
            Text(copy.t('sounds.presets'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            SizedBox(
              height: 116 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: SoundPreset.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final p = SoundPreset.all[i];
                  final locked = p.premium && !premium;
                  return _Chip(
                    sticker: p.icon,
                    label: copy.t('sounds.preset.${p.key}'),
                    locked: locked,
                    onTap: () async {
                      if (await _allowed(p.premium)) await mixer.applyPreset(p);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(copy.t('sounds.layers'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
              children: [
                for (final l in SoundLayer.values)
                  _LayerTile(
                    layer: l,
                    label: copy.t('sounds.layer.${l.name}'),
                    volumeLabel: copy.t('sounds.volume', {'item': copy.t('sounds.layer.${l.name}')}),
                    on: mixer.isOn(l),
                    volume: mixer.volumes[l] ?? 0.7,
                    locked: !freeSoundLayers.contains(l) && !premium,
                    onTap: () async {
                      if (!await _allowed(!freeSoundLayers.contains(l))) return;
                      await mixer.toggle(l);
                      if (mixer.isOn(l) && !mixer.playing) await mixer.play();
                    },
                    onVolume: (v) => mixer.setVolume(l, v),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(copy.t('sounds.timer'), style: const TextStyle(color: DS.onDark, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in const [0, 15, 30, 60])
                ChoiceChip(
                  label: Text(m == 0 ? copy.t('sounds.timer.off') : copy.t('sounds.timer.min', {'n': m})),
                  selected: m == 0 ? left == null : false,
                  onSelected: (_) => mixer.setSleepTimer(m == 0 ? null : Duration(minutes: m)),
                ),
            ]),
            if (left != null) ...[
              const SizedBox(height: 6),
              Text(copy.t('sounds.timer.left', {'time': toPersianDigits('${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}')}),
                  style: const TextStyle(color: DS.onDark)),
            ],
            const SizedBox(height: 24),
            if (mixer.volumes.isEmpty)
              Text(copy.t('sounds.empty'), textAlign: TextAlign.center, style: const TextStyle(color: DS.glyphDim, fontSize: 15))
            else
              ChunkyButton(
                label: copy.t(mixer.playing ? 'sounds.pause' : 'sounds.play'),
                icon: mixer.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onPressed: () => mixer.playing ? mixer.pause() : mixer.play(),
              ),
          ]),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.sticker, required this.label, required this.locked, required this.onTap});
  final String sticker, label;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 96,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: DS.glass, borderRadius: BorderRadius.circular(22)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(clipBehavior: Clip.none, children: [
                  EmojiArt(sticker, size: 44),
                  if (locked) const PositionedDirectional(end: -6, bottom: -4, child: EmojiArt('misc/padlock', size: 20, fallback: 'ui/lock')),
                ]),
                const SizedBox(height: 6),
                Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: DS.onDark, fontSize: 13, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
      );
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({required this.layer, required this.label, required this.volumeLabel, required this.on, required this.volume, required this.locked, required this.onTap, required this.onVolume});
  final SoundLayer layer;
  final String label, volumeLabel;
  final bool on, locked;
  final double volume;
  final VoidCallback onTap;
  final ValueChanged<double> onVolume;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: on ? DS.premiumCard : DS.glass,
          borderRadius: BorderRadius.circular(24),
          border: on ? Border.all(color: DS.onDark, width: 3) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(children: [
          Expanded(
            child: Semantics(
              button: true,
              toggled: on,
              label: label,
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      EmojiArt(soundLayerIcon[layer]!, size: 42),
                      if (locked) const PositionedDirectional(end: -6, bottom: -4, child: EmojiArt('misc/padlock', size: 18, fallback: 'ui/lock')),
                    ]),
                    const SizedBox(height: 4),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: DS.onDark, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: on
                ? Semantics(
                    label: volumeLabel,
                    child: SliderTheme(
                      data: const SliderThemeData(trackHeight: 3, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7), overlayShape: RoundSliderOverlayShape(overlayRadius: 12)),
                      child: Slider(value: volume, onChanged: onVolume, activeColor: DS.onDark, inactiveColor: DS.glyphDim),
                    ),
                  )
                : null,
          ),
        ]),
      );
}
