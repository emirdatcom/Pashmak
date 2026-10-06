import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/version.dart';
import '../../core/widgets/widgets.dart';
import '../system/force_update_screen.dart' show SoftUpdateBanner;

/// The five tabs, in order (the bar is RTL, so the first one, home, is at the right).
class _Tab {
  const _Tab(this.route, this.navKey, this.emoji, this.background, {this.onDark = false});
  final String route;
  final String navKey;
  final String emoji;
  final Color background;
  final bool onDark;
}

const _tabs = [
  _Tab(Routes.home, 'nav.home', 'nav/home', DS.bgHomeGround, onDark: true),
  _Tab(Routes.quests, 'nav.quests', 'nav/quests', DS.bgQuests, onDark: true),
  _Tab(Routes.shop, 'nav.shop', 'nav/shop', DS.bgShopPanel, onDark: true),
  _Tab(Routes.bag, 'nav.bag', 'misc/bag', DS.bgBag),
  _Tab(Routes.cat, 'nav.cat', 'animals/cat', DS.bgCat),
];

/// Index of the tab that owns [location] (a sub-route of a tab keeps that tab selected).
int tabIndexFor(String location) {
  final i = _tabs.indexWhere((t) => location == t.route || location.startsWith('${t.route}/'));
  return i < 0 ? 0 : i;
}

/// Shell with the colour-following bottom bar (docs/design-system.md §1).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final config = ref.watch(appConfigProvider);
    final app = ref.watch(appVersionProvider);
    final showSoft = !ref.watch(softUpdateDismissedProvider) && config.recommendedVersion.isNotEmpty && _older(app, config.recommendedVersion);
    final index = tabIndexFor(location);
    return Scaffold(
      body: Column(children: [
        if (showSoft) const SoftUpdateBanner(),
        Expanded(child: child),
      ]),
      bottomNavigationBar: BottomTabBar(
        background: _tabs[index].background,
        index: index,
        onSelected: (i) => context.go(_tabs[i].route),
        tabs: [for (final t in _tabs) TabSpec(emoji: t.emoji, label: copy.t(t.navKey), onDark: t.onDark)],
      ),
    );
  }

  bool _older(String a, String b) => a != b && compareVersions(a, b) < 0;
}
