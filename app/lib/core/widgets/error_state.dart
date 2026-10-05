import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Gentle error with a retry button (never a stack trace, never blame).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.retryLabel, required this.onRetry});
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(child: Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ]),
        ),
      );
}
