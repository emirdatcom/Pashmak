import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Chat bubble with a speaker name chip (the shopkeeper, the cat).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text, this.speaker});
  final String text;
  final String? speaker;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: speaker == null ? text : '$speaker: $text',
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (speaker != null)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: DS.card, borderRadius: BorderRadius.circular(12)),
                child: Text(speaker!, style: const TextStyle(color: DS.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: DS.card, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: DS.shadow, blurRadius: 6, offset: Offset(0, 2))]),
              child: Text(text, style: const TextStyle(color: DS.textPrimary, fontSize: 15, height: 1.5)),
            ),
          ]),
        ),
      );
}
