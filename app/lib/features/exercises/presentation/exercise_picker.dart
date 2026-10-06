import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/content_repository.dart';
import '../../../core/content/copy_resolver.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../core_loop_providers.dart';
import '../../goals/presentation/goal_sheets.dart' show RoundCloseButton;

/// Every exercise of the bundled / downloaded pack.
List<Map<String, dynamic>> exerciseCatalog(ContentRepository content) => ((content.entries('exercises') as List?) ?? const []).cast<Map<String, dynamic>>();

Map<String, dynamic>? exerciseByKey(ContentRepository content, String? key) {
  if (key == null) return null;
  for (final e in exerciseCatalog(content)) {
    if (e['key'] == key) return e;
  }
  return null;
}

/// reflection | breathing | grounding | movement | timer (older packs have no `kind`).
String exerciseKind(Map<String, dynamic> e) => (e['kind'] as String?) ?? (e['type'] == 'journal_prompt' ? 'reflection' : 'breathing');

const _treats = ['candy_pink', 'candy_purple', 'gummy_bear', 'lollipop', 'chocolate', 'candy_corn', 'jelly_beans', 'swirl_candy'];

/// The little treat shown beside an exercise: decorative, always the same one for a given exercise.
String exerciseTreat(String key) => 'treats/${_treats[key.codeUnits.fold<int>(0, (a, c) => a + c) % _treats.length]}';

/// The sticker of an exercise on a soft blob coloured by its kind.
class ExerciseBlob extends StatelessWidget {
  const ExerciseBlob(this.exercise, {super.key, this.size = 56});
  final Map<String, dynamic> exercise;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.12,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DS.exerciseKind(exerciseKind(exercise)),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(size * 0.42),
              topRight: Radius.circular(size * 0.34),
              bottomLeft: Radius.circular(size * 0.34),
              bottomRight: Radius.circular(size * 0.46),
            ),
          ),
          child: Transform.rotate(angle: 0.12, child: EmojiArt((exercise['icon'] as String?) ?? 'body/lungs', size: size * 0.62)),
        ),
      );
}

/// One exercise: blob, name, one-line description and its length in minutes.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({super.key, required this.exercise, required this.copy, required this.onTap, this.trailing});
  final Map<String, dynamic> exercise;
  final CopyResolver copy;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final key = exercise['key'] as String;
    final minutes = ((exercise['duration_s'] as int) / 60).ceil();
    return RoundCard(
      padding: const EdgeInsets.all(12),
      semanticLabel: copy.t('exercise.$key.name'),
      onTap: onTap,
      child: Row(children: [
        ExerciseBlob(exercise),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(copy.t('exercise.$key.name'), style: const TextStyle(color: DS.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(copy.t('exercise.$key.desc'), style: const TextStyle(color: DS.textSecondary, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          ?trailing,
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(copy.t('exercise.length.min', {'n': minutes}), style: const TextStyle(color: DS.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            EmojiArt(exerciseTreat(key), size: 22),
          ]),
        ]),
      ]),
    );
  }
}

/// "Link an exercise": a searchable list of every exercise; pops the chosen key.
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePickerScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final premium = ref.watch(premiumProvider);
    final svc = ref.watch(exerciseServiceProvider);
    final q = normalizeDigits(_query.text.trim());
    final list = [
      for (final e in exerciseCatalog(ref.watch(contentRepositoryProvider)))
        if (q.isEmpty || normalizeDigits('${copy.t('exercise.${e['key']}.name')} ${copy.t('exercise.${e['key']}.desc')}').contains(q)) e,
    ];
    return Scaffold(
      backgroundColor: DS.bgHomeGround,
      body: SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: const BoxDecoration(color: DS.sheetBg, borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusSheet))),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(alignment: AlignmentDirectional.centerStart, child: RoundCloseButton(label: copy.t('common.close'), onPressed: () => Navigator.pop(context))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: copy.t('exercise.picker.search'),
                  prefixIcon: const Padding(padding: EdgeInsets.all(14), child: EmojiArt('ui/search', size: 22)),
                  filled: true,
                  fillColor: DS.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusOutlineCard), borderSide: const BorderSide(color: DS.outline, width: 2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radiusOutlineCard), borderSide: const BorderSide(color: DS.primaryGreen, width: 2)),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text(copy.t('exercise.picker.empty'), style: const TextStyle(color: DS.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => ExerciseRow(
                        exercise: list[i],
                        copy: copy,
                        trailing: svc.isLocked(list[i]['key'] as String, isPremium: premium) ? const EmojiArt('ui/lock', size: 18) : null,
                        onTap: () => Navigator.pop(context, list[i]['key'] as String),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
