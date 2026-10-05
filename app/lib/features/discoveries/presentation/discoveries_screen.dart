import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';

/// Discoveries collection: categories with found items by name and "???" for the rest, plus the counter.
class DiscoveriesScreen extends ConsumerWidget {
  const DiscoveriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final entries = ((ref.watch(contentRepositoryProvider).entries('discoveries') as List?) ?? const []).cast<Map<String, dynamic>>();
    final found = ref.watch(foundDiscoveriesProvider).value ?? const <String>{};
    final cats = <String>[for (final e in entries) e['category'] as String]..sort();
    final order = {for (final c in cats) c: 0}.keys.toList();
    return Scaffold(
      backgroundColor: DS.bgCat,
      appBar: AppBar(title: Text(copy.t('discoveries.title')), backgroundColor: DS.bgCat),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Semantics(
          label: copy.t('discoveries.count', {'n': found.length}),
          child: ExcludeSemantics(
            child: Center(child: Text('${toPersianDigits(found.length)} / ${toPersianDigits(entries.length)}', style: const TextStyle(color: DS.textPrimary, fontSize: 22, fontWeight: FontWeight.w800))),
          ),
        ),
        const SizedBox(height: 12),
        for (final c in order) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(copy.t('discovery.category.$c'), style: const TextStyle(color: DS.textSecondary, fontWeight: FontWeight.w700))),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              for (final e in entries.where((e) => e['category'] == c))
                Semantics(
                  label: found.contains(e['key']) ? copy.t(e['name_key'] as String) : copy.t('discoveries.unknown'),
                  child: ExcludeSemantics(
                    child: RoundCard(
                      padding: const EdgeInsets.all(8),
                      color: found.contains(e['key']) ? DS.card : DS.neutralButton,
                      child: Center(
                        child: Text(found.contains(e['key']) ? copy.t(e['name_key'] as String) : copy.t('discoveries.unknown'),
                            textAlign: TextAlign.center, style: TextStyle(color: found.contains(e['key']) ? DS.textPrimary : DS.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ]),
    );
  }
}
