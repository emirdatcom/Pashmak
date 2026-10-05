import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../core_loop_providers.dart';

class WalletBar extends ConsumerWidget {
  const WalletBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(walletProvider).value;
    final copy = ref.watch(copyProvider);
    final cap = ref.watch(appConfigProvider).energyCap;
    Widget chip(IconData icon, String label, String value) => Semantics(
          label: '$label $value',
          child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppColors.orangeDark),
              const SizedBox(width: AppSpacing.xs),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      chip(Icons.bolt, copy.t('wallet.energy'), '${toPersianDigits(w?.energy ?? 0)}/${toPersianDigits(cap)}'),
      chip(Icons.monetization_on_outlined, copy.t('wallet.coins'), toPersianDigits(w?.coins ?? 0)),
    ]);
  }
}
