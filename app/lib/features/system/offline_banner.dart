import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) => Connectivity().onConnectivityChanged);

/// Show only on screens that need the network (purchases, restore…): offline is normal elsewhere.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).maybeWhen(
          data: (r) => !r.contains(ConnectivityResult.none),
          orElse: () => true,
        );
    if (online) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.creamDeep,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(ref.watch(copyProvider).t('system.offline'), textAlign: TextAlign.center),
    );
  }
}
