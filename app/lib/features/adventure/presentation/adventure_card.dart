import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';

/// Home card for the automatic daily adventure: hidden when nothing is going on, "away" with a countdown while the
/// cat is out, and "adventure finished" (what {CAT_NAME} found) once it is back.
class AdventureCard extends ConsumerWidget {
  const AdventureCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    ref.watch(tickProvider);
    final adv = ref.watch(currentAdventureProvider).value;
    if (adv == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).now();
    final returned = adv.status == 'returned' || now.millisecondsSinceEpoch >= adv.endsAt;
    final String title;
    final String? subtitle;
    if (returned) {
      title = copy.t('home.adventure.card_found', {'item': copy.t('home.adventure.something')});
      subtitle = copy.t('home.adventure.card_open');
    } else {
      final mins = DateTime.fromMillisecondsSinceEpoch(adv.endsAt).difference(now).inMinutes + 1;
      title = copy.t('adventure.away', {'place': copy.t('adventure.location.${adv.locationKey}.name')});
      subtitle = copy.t('adventure.eta', {'n': mins});
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Material(
        color: DS.glassDark,
        borderRadius: BorderRadius.circular(DS.radiusHomeCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.adventure),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: DS.progressYellow, borderRadius: BorderRadius.circular(17)),
                    child: EmojiArt(returned ? 'misc/treasure_chest' : 'misc/compass', size: 34),
                  ),
                  if (returned) const PositionedDirectional(end: 0, bottom: 0, child: EmojiArt('ui/check', size: 20)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: DS.onDark, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: DS.onDark, fontSize: 14)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

String formatMinutes(int n) => toPersianDigits(n);
