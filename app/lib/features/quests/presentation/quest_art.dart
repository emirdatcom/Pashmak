import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/emoji_art.dart';

/// How a quest card is dressed: a sticker on a coloured rounded tile, an optional kicker line above the title and an
/// optional sticker riding the progress bar. [fallback] is drawn until new art ([sticker]) is in the bundle.
class QuestArt {
  const QuestArt(this.sticker, this.tile, {this.fallback, this.kickerKey, this.progressEmoji, this.rays = false});
  final String sticker;
  final Color tile;
  final String? fallback;
  final String? kickerKey;
  final String? progressEmoji;

  /// A soft sunburst behind the sticker (the daily reward).
  final bool rays;

  static const _byKey = <String, QuestArt>{
    // daily
    'daily_claim': QuestArt('misc/crystal', DS.questTileGrey, kickerKey: 'quest.kicker.daily_claim', rays: true),
    'checkin_word': QuestArt('connection/speech_bubble', DS.questTileBlue),
    'breathe_once': QuestArt('calm/box_breathing', DS.questTilePurple),
    'tick_one': QuestArt('misc/checklist', DS.questTileGreen),
    'tick_three': QuestArt('misc/checklist', DS.questTileGreen),
    'tick_five': QuestArt('misc/checklist', DS.questTileGreen),
    'reflect_one': QuestArt('misc/notepad_pencil', DS.questTilePurple, kickerKey: 'quest.kicker.reflect_one'),
    'energy_ten': QuestArt('ui/bolt', DS.questTileOrange, progressEmoji: 'ui/bolt'),
    'shop_peek': QuestArt('nav/shop', DS.questTilePink),
    'check_cat': QuestArt('animals/cat', DS.questTileTeal),
    // special
    'grow_young': QuestArt('nature/seedling', DS.questTileOrange, kickerKey: 'quest.kicker.grow'),
    'grow_adult': QuestArt('nature/seedling', DS.questTileOrange, kickerKey: 'quest.kicker.grow'),
    'first_outfit': QuestArt('clothing/tshirt', DS.questTileBlue),
    'first_furniture': QuestArt('home/lamp', DS.questTileTeal),
    'visit_two': QuestArt('misc/map', DS.questTileGreen),
    'three_days': QuestArt('misc/desk_calendar', DS.questTilePink),
    'first_discovery': QuestArt('misc/magnifier', DS.questTilePurple),
    'ten_goals': QuestArt('misc/medal_first', DS.questTileGrey, rays: true),
  };

  static const _default = QuestArt('misc/star', DS.questTileOrange);

  static QuestArt of(String key) => _byKey[key] ?? _default;
}

/// The rounded tile holding a quest's sticker.
class QuestTile extends StatelessWidget {
  const QuestTile({super.key, required this.art, this.size = 64});
  final QuestArt art;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: art.tile,
          borderRadius: BorderRadius.circular(size * 0.24),
          border: Border.all(color: Color.lerp(art.tile, DS.textDeep, 0.15)!, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(alignment: Alignment.center, children: [
          if (art.rays) Positioned.fill(child: CustomPaint(painter: _Rays())),
          EmojiArt(art.sticker, size: size * 0.7, fallback: art.fallback),
        ]),
      );
}

class _Rays extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    final p = Paint()..color = DS.questRay;
    const n = 12;
    const half = math.pi / n / 2;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - half), c.dy + r * math.sin(a - half))
        ..lineTo(c.dx + r * math.cos(a + half), c.dy + r * math.sin(a + half))
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => false;
}
