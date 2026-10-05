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
      child: RoundCard(
        color: returned ? DS.doneBg : DS.card,
        onTap: () => context.push(Routes.adventure),
        child: Row(children: [
          Icon(returned ? Icons.card_giftcard : Icons.explore, color: returned ? DS.doneText : DS.areaFocus, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: DS.textSecondary, fontSize: 13)),
            ]),
          ),
          const Icon(Icons.chevron_left, color: DS.textSecondary),
        ]),
      ),
    );
  }
}

String formatMinutes(int n) => toPersianDigits(n);
