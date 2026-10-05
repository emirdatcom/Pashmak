import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../core_loop_providers.dart';

/// Home card: start / in progress (with countdown) / returned.
class AdventureCard extends ConsumerWidget {
  const AdventureCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    ref.watch(tickProvider);
    final adv = ref.watch(currentAdventureProvider).value;
    final now = ref.watch(clockProvider).now();
    String title, subtitle;
    IconData icon;
    if (adv == null) {
      title = copy.t('adventure.title');
      subtitle = copy.t('home.adventure.start');
      icon = Icons.explore_outlined;
    } else if (adv.status == 'returned' || now.millisecondsSinceEpoch >= adv.endsAt) {
      title = copy.t('adventure.returned');
      subtitle = copy.t('adventure.claim');
      icon = Icons.card_giftcard;
    } else {
      final left = DateTime.fromMillisecondsSinceEpoch(adv.endsAt).difference(now);
      final mins = left.inMinutes + 1;
      title = copy.t('adventure.away', {'place': copy.t('adventure.location.${adv.locationKey}.name')});
      subtitle = copy.t('adventure.eta', {'n': mins});
      icon = Icons.pets;
    }
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => context.push(Routes.adventure),
      ),
    );
  }
}

String formatMinutes(int n) => toPersianDigits(n);
