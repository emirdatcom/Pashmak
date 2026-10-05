import 'package:flutter/material.dart';

import '../l10n/digits.dart';
import '../theme/tokens.dart';
import 'premium_badge.dart';

/// Shop grid tile: art area, name, and a price (or a lock for premium items / a check when owned).
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.name,
    required this.art,
    required this.onTap,
    this.priceCoins,
    this.premiumLabel,
    this.owned = false,
    this.ownedLabel,
    this.semanticLabel,
    this.onPanel = false,
  });
  final String name;
  final Widget art;
  final VoidCallback? onTap;
  final int? priceCoins;
  final String? premiumLabel; // set for premium-only items the user cannot use yet
  final bool owned;
  final String? ownedLabel;
  final String? semanticLabel;

  /// Brown tile on the shop panel (reference look); white text on [DS.shopTile].
  final bool onPanel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel ?? name,
        child: ExcludeSemantics(
          child: Material(
            color: onPanel ? DS.shopTile : DS.card,
            borderRadius: BorderRadius.circular(DS.radiusCard),
            child: InkWell(
              borderRadius: BorderRadius.circular(DS.radiusCard),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(child: Center(child: art)),
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: onPanel ? DS.onDark : DS.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (owned)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle, size: 16, color: DS.doneText),
                      const SizedBox(width: 4),
                      Text(ownedLabel ?? '', style: const TextStyle(color: DS.doneText, fontSize: 12, fontWeight: FontWeight.w700)),
                    ])
                  else if (premiumLabel != null)
                    PremiumBadge(label: premiumLabel!)
                  else if (priceCoins != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.monetization_on, size: 16, color: DS.coin),
                      const SizedBox(width: 4),
                      Text(toPersianDigits(priceCoins!), style: TextStyle(color: onPanel ? DS.onDark : DS.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                ]),
              ),
            ),
          ),
        ),
      );
}
