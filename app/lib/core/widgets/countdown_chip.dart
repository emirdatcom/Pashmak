import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Refresh icon + a ready-made remaining-time label ("۱۲ ساعت ۲۷ دقیقه"; the caller formats it with copy).
class CountdownChip extends StatelessWidget {
  const CountdownChip({super.key, required this.label, this.onDark = true, this.semanticLabel});
  final String label;
  final bool onDark;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? DS.onDark : DS.textPrimary;
    return Semantics(
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.refresh, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}
