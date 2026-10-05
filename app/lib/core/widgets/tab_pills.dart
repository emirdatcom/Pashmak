import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class PillTab {
  const PillTab(this.id, this.label);
  final String id;
  final String label;
}

/// Horizontally scrollable pill tabs (suggestion tabs, exercise tabs).
class TabPills extends StatelessWidget {
  const TabPills({super.key, required this.tabs, required this.selected, required this.onSelected, this.onDark = false});
  final List<PillTab> tabs;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool onDark;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tabs.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final t = tabs[i];
            final on = t.id == selected;
            final bg = on ? (onDark ? DS.card : DS.textPrimary) : (onDark ? DS.scrim : DS.neutralButton);
            final fg = on ? (onDark ? DS.textPrimary : DS.onDark) : (onDark ? DS.onDark : DS.textPrimary);
            return Semantics(
              button: true,
              selected: on,
              label: t.label,
              child: ExcludeSemantics(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onSelected(t.id),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
                        child: Text(t.label, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}
