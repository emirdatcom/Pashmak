import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class TabSpec {
  const TabSpec({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color; // the colour of the icon (icons are coloured, not outlined)
}

/// Bottom bar whose background follows the current tab. The selected tab gets a soft rounded highlight.
class BottomTabBar extends StatelessWidget {
  const BottomTabBar({super.key, required this.tabs, required this.index, required this.onSelected, required this.background});
  final List<TabSpec> tabs;
  final int index;
  final ValueChanged<int> onSelected;
  final Color background;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: tabs[i].label,
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () => onSelected(i),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: i == index ? DS.card.withValues(alpha: 0.55) : null, borderRadius: BorderRadius.circular(18)),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(tabs[i].icon, color: tabs[i].color, size: 28),
                              Text(tabs[i].label, style: const TextStyle(color: DS.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
