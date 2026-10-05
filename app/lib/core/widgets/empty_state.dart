import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Calm "nothing here yet" block: [message] (already resolved copy) and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.pets_outlined, this.actionLabel, this.onAction});
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(child: Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}
