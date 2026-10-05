import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Shown when the encrypted database cannot be opened (Keystore failure, missing cipher, corrupt file).
/// Content packs may not be loaded yet, so the text is passed in (bundled copy or a safe fallback).
class DbErrorScreen extends StatelessWidget {
  const DbErrorScreen({super.key, required this.title, required this.body, required this.retryLabel, required this.onRetry});
  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            ]),
          ),
        ),
      );
}
