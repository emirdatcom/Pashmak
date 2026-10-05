import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// White card with 28dp corners and a very soft shadow.
class RoundCard extends StatelessWidget {
  const RoundCard({super.key, required this.child, this.color = DS.card, this.padding = const EdgeInsets.all(16), this.onTap, this.margin, this.semanticLabel});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(DS.radiusCard), boxShadow: const [BoxShadow(color: DS.shadow, blurRadius: 8, offset: Offset(0, 2))]),
      child: child,
    );
    if (onTap == null) return semanticLabel == null ? body : Semantics(container: true, label: semanticLabel, child: body);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(type: MaterialType.transparency, child: InkWell(borderRadius: BorderRadius.circular(DS.radiusCard), onTap: onTap, child: body)),
    );
  }
}
