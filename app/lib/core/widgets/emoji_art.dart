import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One sticker from `assets/art/emoji/` (see its `manifest.json`); [id] is `<folder>/<name>`, e.g. `food/matcha`.
/// Decorative: callers own the semantics label.
class EmojiArt extends StatelessWidget {
  const EmojiArt(this.id, {super.key, this.size = 24});
  final String id;
  final double size;

  /// Stickers with a direction: drawn for left-to-right, mirrored in RTL.
  static const _directional = {'ui/arrow', 'ui/undo'};

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/art/emoji/$id.png',
        width: size,
        height: size,
        // Sources are 384px; decode at the drawn size to keep memory low on weak phones.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        matchTextDirection: _directional.contains(id),
        // A sticker missing from the bundle leaves an empty box, not an error mark.
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
      );
}

/// A one-colour glyph from `assets/art/emoji/glyph/` (stored white), painted in [color]: close, plus, check, play,
/// chevrons, … Glyphs that point somewhere are drawn for left-to-right and mirrored in RTL.
class GlyphArt extends StatelessWidget {
  const GlyphArt(this.name, {super.key, this.size = 24, this.color = DS.textSecondary, this.quarterTurns = 0});
  final String name;
  final double size;
  final Color color;
  final int quarterTurns;

  static const _directional = {'chevron_right', 'play', 'undo'};

  @override
  Widget build(BuildContext context) => RotatedBox(
        quarterTurns: quarterTurns,
        child: Image.asset(
          'assets/art/emoji/glyph/$name.png',
          width: size,
          height: size,
          color: color,
          colorBlendMode: BlendMode.srcIn,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          matchTextDirection: _directional.contains(name),
          errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
        ),
      );
}
