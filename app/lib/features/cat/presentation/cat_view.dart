import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../core_loop_providers.dart';

/// The cat for the current state, with a screen-reader description.
class CatView extends ConsumerWidget {
  const CatView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catStateProvider);
    final copy = ref.watch(copyProvider);
    return Semantics(
      label: copy.t('cat.semantics.${state.activity.name == 'away' ? 'away' : state.mood.name}'),
      image: true,
      child: ExcludeSemantics(child: ref.watch(catRendererProvider).build(context, state)),
    );
  }
}
