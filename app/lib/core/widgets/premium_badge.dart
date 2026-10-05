import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// "Premium" marker: blue pill with a yellow lock.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, required this.label, this.locked = true});
  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: DS.premiumBadge, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (locked) const Icon(Icons.lock, size: 14, color: DS.lockYellow),
          if (locked) const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: DS.onDark, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}
