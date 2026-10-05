import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Shown only until the router redirect fires.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
}
