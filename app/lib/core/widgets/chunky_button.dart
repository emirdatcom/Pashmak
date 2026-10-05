import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 3D button of the redesign: a 4dp darker bottom edge that collapses (the button moves down 4dp) while pressed.
/// Animation (80ms) is skipped when the platform asks for reduced motion.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = DS.primaryGreen,
    this.edgeColor = DS.primaryGreenEdge,
    this.textColor = DS.onPrimary,
    this.expand = true,
    this.height = 52,
  });

  /// A neutral (grey) variant used for secondary actions.
  const ChunkyButton.neutral({super.key, required this.label, required this.onPressed, this.icon, this.expand = true, this.height = 52})
      : color = DS.neutralButton,
        edgeColor = DS.neutralButtonEdge,
        textColor = DS.textPrimary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color edgeColor;
  final Color textColor;
  final bool expand;
  final double height;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduce = MediaQuery.of(context).disableAnimations;
    final dur = reduce ? Duration.zero : const Duration(milliseconds: 80);
    final edge = _down || !enabled ? 0.0 : DS.buttonEdge;
    final face = AnimatedContainer(
      duration: dur,
      margin: EdgeInsets.only(top: DS.buttonEdge - edge),
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: enabled ? widget.color : DS.neutralButton,
        borderRadius: BorderRadius.circular(DS.radiusButton),
        boxShadow: [BoxShadow(color: enabled ? widget.edgeColor : DS.neutralButtonEdge, offset: Offset(0, edge))],
      ),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (widget.icon != null) Icon(widget.icon, color: enabled ? widget.textColor : DS.textSecondary),
        if (widget.icon != null && widget.label.isNotEmpty) const SizedBox(width: 8),
        if (widget.label.isNotEmpty)
        Flexible(
          child: Text(widget.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(color: enabled ? widget.textColor : DS.textSecondary, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
        ),
      ]),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.height + DS.buttonEdge, minWidth: widget.expand ? double.infinity : 0),
            child: widget.expand ? face : IntrinsicWidth(child: face),
          ),
        ),
      ),
    );
  }
}
