import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../core_loop_providers.dart';
import '../../notifications/data/notification_scheduler.dart';

/// Settings home. Sections are filled by later prompts (privacy, backup, account…).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('settings.title'))),
      body: ListView(children: [
        ListTile(leading: const Icon(Icons.notifications_none), title: Text(copy.t('settings.notifications.title')), trailing: const Icon(Icons.chevron_left), onTap: () => context.push('${Routes.settings}/notifications')),
        ListTile(leading: const Icon(Icons.favorite_border), title: Text(copy.t('help.title')), trailing: const Icon(Icons.chevron_left), onTap: () => context.push(Routes.safety)),
      ]),
    );
  }
}

final _permissionProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(notificationServiceProvider).hasPermission());

/// `/settings/notifications`: per-type switches, times, quiet hours, exact alarms, troubleshooting.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<NotificationSettingsScreen> {
  final Map<String, String> _values = {};
  bool _loaded = false;

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final cfg = ref.read(appConfigProvider);
    for (final t in defaultNotifTypes.keys) {
      _values[NotifSettingKeys.enabled(t)] = await db.setting(NotifSettingKeys.enabled(t)) ?? '${defaultNotifTypes[t]}';
    }
    _values[NotifSettingKeys.morning] = await db.setting(NotifSettingKeys.morning) ?? '${parseHHmm(cfg.notifMorningTime)}';
    _values[NotifSettingKeys.evening] = await db.setting(NotifSettingKeys.evening) ?? '${parseHHmm(cfg.notifEveningTime)}';
    _values[NotifSettingKeys.quietStart] = await db.setting(NotifSettingKeys.quietStart) ?? '${parseHHmm(cfg.notifQuietStart)}';
    _values[NotifSettingKeys.quietEnd] = await db.setting(NotifSettingKeys.quietEnd) ?? '${parseHHmm(cfg.notifQuietEnd)}';
    _values[NotifSettingKeys.exactAlarms] = await db.setting(NotifSettingKeys.exactAlarms) ?? 'false';
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _set(String key, String value) async {
    await ref.read(databaseProvider).setSetting(key, value);
    setState(() => _values[key] = value);
    await ref.read(notificationSchedulerProvider).replan();
  }

  Future<void> _pickTime(String key) async {
    final cur = int.parse(_values[key]!);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t != null) await _set(key, '${t.hour * 60 + t.minute}');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      _load();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final copy = ref.watch(copyProvider);
    final cfg = ref.watch(appConfigProvider);
    final permission = ref.watch(_permissionProvider).value ?? true;
    String time(String key) => JalaliFormatter.time(int.parse(_values[key]!));
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('settings.notifications.title'))),
      body: ListView(children: [
        if (!permission)
          MaterialBanner(
            content: Text(copy.t('settings.notifications.permission.off')),
            actions: [
              TextButton(
                onPressed: () async {
                  await ref.read(notificationServiceProvider).requestPermission();
                  ref.invalidate(_permissionProvider);
                },
                child: Text(copy.t('settings.notifications.permission.ask')),
              ),
            ],
          ),
        for (final t in defaultNotifTypes.keys)
          if (cfg.notifTypeEnabled(t)) // remotely disabled types are hidden
            SwitchListTile(title: Text(copy.t('settings.notifications.type.$t')), value: _values[NotifSettingKeys.enabled(t)] == 'true', onChanged: (v) => _set(NotifSettingKeys.enabled(t), '$v')),
        const Divider(),
        ListTile(title: Text(copy.t('settings.notifications.morning_time')), trailing: Text(time(NotifSettingKeys.morning)), onTap: () => _pickTime(NotifSettingKeys.morning)),
        ListTile(title: Text(copy.t('settings.notifications.evening_time')), trailing: Text(time(NotifSettingKeys.evening)), onTap: () => _pickTime(NotifSettingKeys.evening)),
        ListTile(title: Text('${copy.t('settings.notifications.quiet')}: ${copy.t('settings.notifications.quiet_from')} ${time(NotifSettingKeys.quietStart)} ${copy.t('settings.notifications.quiet_to')} ${time(NotifSettingKeys.quietEnd)}'), onTap: () async {
          await _pickTime(NotifSettingKeys.quietStart);
          await _pickTime(NotifSettingKeys.quietEnd);
        }),
        SwitchListTile(
          title: Text(copy.t('settings.notifications.exact')),
          subtitle: Text(copy.t('settings.notifications.exact.hint')),
          value: _values[NotifSettingKeys.exactAlarms] == 'true',
          onChanged: (v) => _set(NotifSettingKeys.exactAlarms, '$v'),
        ),
        const Divider(),
        ExpansionTile(
          title: Text(copy.t('settings.notifications.troubleshoot')),
          childrenPadding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(copy.t('settings.notifications.troubleshoot.body')),
            for (final m in ['xiaomi', 'samsung', 'huawei', 'other']) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(copy.t('settings.notifications.troubleshoot.$m'))),
          ],
        ),
      ]),
    );
  }
}
