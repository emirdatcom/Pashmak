import 'package:flutter/material.dart';

import '../l10n/digits.dart';
import '../theme/tokens.dart';
import 'emoji_art.dart';

/// Yellow progress bar on a light rail with the "value/max" text centered on it.
class ProgressPill extends StatelessWidget {
  const ProgressPill({super.key, required this.value, required this.max, this.height = 24, this.label, this.showText = true, this.endEmoji, this.knob = false});
  final int value;
  final int max;
  final double height;
  final String? label; // semantics text, e.g. "۳ از ۷"
  final bool showText;

  /// Sticker riding at the end of the fill (e.g. the reward the quest earns).
  final String? endEmoji;

  /// Always show at least a round knob of fill, even at zero (quest cards).
  final bool knob;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final text = '${toPersianDigits(value > max ? max : value)}/${toPersianDigits(max)}';
    return Semantics(
      label: label ?? text,
      value: text,
      child: ExcludeSemantics(
        child: Container(
          height: height,
          decoration: BoxDecoration(color: DS.progressRail, borderRadius: BorderRadius.circular(height)),
          child: Stack(alignment: Alignment.center, children: [
            LayoutBuilder(
              builder: (context, c) {
                final floor = knob || endEmoji != null ? height * 1.6 : 0.0;
                final w = (c.maxWidth * f).clamp(floor < c.maxWidth ? floor : c.maxWidth, c.maxWidth);
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedContainer(
                    duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
                    width: w,
                    height: height,
                    decoration: BoxDecoration(color: DS.progressYellow, borderRadius: BorderRadius.circular(height)),
                    alignment: AlignmentDirectional.centerEnd,
                    child: endEmoji == null ? null : EmojiArt(endEmoji!, size: height),
                  ),
                );
              },
            ),
            if (showText) Text(text, style: const TextStyle(color: DS.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
