import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'emoji_art.dart';

class TabSpec {
  const TabSpec({required this.emoji, required this.label, this.onDark = false});
  final String emoji; // sticker id, see EmojiArt
  final String label;
  final bool onDark; // white labels and a glass highlight, for tabs with a mid or dark background
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: i == index ? (tabs[index].onDark ? DS.glass : DS.card.withValues(alpha: 0.55)) : null, borderRadius: BorderRadius.circular(18)),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              EmojiArt(tabs[i].emoji, size: 32),
                              Text(tabs[i].label, style: TextStyle(color: tabs[index].onDark ? DS.onDark : DS.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
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
