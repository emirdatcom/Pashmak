import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'features/core_loop_providers.dart';
import 'core/theme/app_theme.dart';

/// Root widget: RTL Persian app with go_router. The Directionality is forced to RTL.
class App extends ConsumerStatefulWidget {
  const App({super.key});
  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription<NotificationTap>? _taps;

  @override
  void initState() {
    super.initState();
    final service = ref.read(notificationServiceProvider);
    _taps = service.onTap.listen(_handleTap);
    if (service is LocalNotificationService) {
      service.launchTap().then((t) {
        if (t != null) _handleTap(t);
      });
    }
  }

  /// Notification tap → log opened_at + analytics, then deep link through go_router.
  Future<void> _handleTap(NotificationTap tap) async {
    await ref.read(notificationSchedulerProvider).onOpened(tap);
    ref.read(routerProvider).go(tap.route);
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // The redesign is light-only for now (dark theme disabled until it is redesigned, docs/22 §3).
      themeMode: ThemeMode.light,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
    );
  }
}
