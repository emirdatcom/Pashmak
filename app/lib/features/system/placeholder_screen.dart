import 'package:flutter/material.dart';

/// Stand-in for screens built in later prompts. Shows the route name (not user-facing copy).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(name, textDirection: TextDirection.ltr)),
        body: Center(child: Text(name, textDirection: TextDirection.ltr)),
      );
}
