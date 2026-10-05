import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Small "hint" pill used on special quests.
class HintButton extends StatelessWidget {
  const HintButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: DS.neutralButton, borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lightbulb_outline, size: 16, color: DS.textPrimary),
                    const SizedBox(width: 4),
                    Text(label, style: const TextStyle(color: DS.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
