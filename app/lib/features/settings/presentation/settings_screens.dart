import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/screen_awake.dart';
import '../../../core/theme/tokens.dart';
import '../../core_loop_providers.dart';
import '../../notifications/data/notification_scheduler.dart';
import '../../onboarding/domain/onboarding_service.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../settings_providers.dart';

/// Settings home (docs/20 §4): notifications, my day, theme, subscription, your data, help, about, contact.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final dayStart = ref.watch(dayStartHourProvider);
    final theme = ref.watch(themeModeProvider);
    final catName = ref.watch(catNameProvider);
    final contact = (ref.watch(contentRepositoryProvider).bundledEntries('brand')['support_contact'] as Map?) ?? const {};
    final email = (contact['email'] as String?) ?? '';
    final channel = (contact['channel_url'] as String?) ?? '';
    ListTile tile(IconData icon, String title, VoidCallback? onTap, {String? subtitle}) => ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: onTap == null ? null : const Icon(Icons.chevron_left),
          onTap: onTap,
        );
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('settings.title'))),
      body: ListView(children: [
        tile(Icons.notifications_none, copy.t('settings.notifications.title'), () => context.push('${Routes.settings}/notifications')),
        tile(Icons.wb_twilight, copy.t('settings.day_start'), () => _pickDayStart(context, ref), subtitle: toPersianDigits(JalaliFormatter.time(dayStart * 60))),
        tile(Icons.brightness_6_outlined, copy.t('settings.theme'), () => _pickTheme(context, ref), subtitle: copy.t('settings.theme.${theme.name}')),
        tile(Icons.pets_outlined, copy.t('settings.cat_name'), () => _renameCat(context, ref), subtitle: catName.isEmpty ? null : catName),
        tile(Icons.workspace_premium_outlined, copy.t('sub.title'), () => context.push(Routes.subscription)),
        tile(Icons.lock_outline, copy.t('settings.privacy.title'), () => context.push('${Routes.settings}/privacy')),
        tile(Icons.favorite_border, copy.t('help.title'), () => context.push(Routes.safety)),
        tile(Icons.info_outline, copy.t('settings.about'), () => context.push('${Routes.settings}/about')),
        tile(Icons.mail_outline, copy.t('settings.contact'), (email.isEmpty && channel.isEmpty) ? null : () => _contact(email, channel),
            subtitle: (email.isEmpty && channel.isEmpty) ? copy.t('settings.contact.none') : null),
      ]),
    );
  }

  Future<void> _contact(String email, String channel) async {
    final uri = email.isNotEmpty ? Uri(scheme: 'mailto', path: email) : Uri.parse(channel);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickDayStart(BuildContext context, WidgetRef ref) async {
    final copy = ref.read(copyProvider);
    final current = ref.read(dayStartHourProvider);
    final h = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(copy.t('settings.day_start')), children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: Text(copy.t('settings.day_start.hint'))),
        for (var i = 0; i <= 6; i++)
          ListTile(selected: i == current, title: Text(toPersianDigits(JalaliFormatter.time(i * 60))), trailing: i == current ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(c, i)),
      ]),
    );
    if (h != null) {
      await ref.read(dayStartHourProvider.notifier).save(h);
      unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.settingsChanged, {'key': 'day_start_hour'}));
      await ref.read(notificationSchedulerProvider).replan();
    }
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final copy = ref.read(copyProvider);
    final current = ref.read(themeModeProvider);
    final m = await showDialog<ThemeMode>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(copy.t('settings.theme')), children: [
        for (final v in ThemeMode.values)
          ListTile(selected: v == current, title: Text(copy.t('settings.theme.${v.name}')), trailing: v == current ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(c, v)),
      ]),
    );
    if (m != null) await ref.read(themeModeProvider.notifier).save(m);
  }

  Future<void> _renameCat(BuildContext context, WidgetRef ref) async {
    final copy = ref.read(copyProvider);
    final svc = ref.read(onboardingServiceProvider);
    final controller = TextEditingController(text: ref.read(catNameProvider).isEmpty ? svc.defaultCatName : ref.read(catNameProvider));
    String? error;
    final name = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(copy.t('settings.cat_name')),
          content: TextField(controller: controller, maxLength: 16, decoration: InputDecoration(errorText: error)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(copy.t('common.cancel'))),
            FilledButton(
              onPressed: () {
                final check = checkCatName(controller.text, ref.read(nameBlocklistProvider));
                if (check == NameCheck.ok) {
                  Navigator.pop(c, controller.text.trim());
                } else {
                  set(() => error = copy.t(check == NameCheck.empty ? 'onboarding.name.error.empty' : check == NameCheck.tooLong ? 'onboarding.name.error.long' : 'onboarding.name.error.blocked'));
                }
              },
              child: Text(copy.t('common.save')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null) return;
    await svc.saveCatName(name);
    ref.read(catNameProvider.notifier).set(name == svc.defaultCatName ? '' : name);
  }
}

/// `/settings/privacy` — "Your data" (docs/80 §4).
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});
  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyState();
}

class _PrivacyState extends ConsumerState<PrivacyScreen> {
  bool _analyticsOff = false;
  bool _hideRecents = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final off = await db.setting('analytics_opt_out') == 'true';
    final hide = await db.setting('hide_recents') == 'true';
    if (!mounted) return;
    setState(() {
      _analyticsOff = off;
      _hideRecents = hide;
    });
  }

  Future<void> _export() async {
    final copy = ref.read(copyProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final json = await ref.read(dataServiceProvider).exportJson();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/export.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')]));
      messenger.showSnackBar(SnackBar(content: Text(copy.t('settings.privacy.export_done'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String titleKey, String bodyKey, String actionKey) async {
    final copy = ref.read(copyProvider);
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(copy.t(titleKey)),
            content: Text(copy.t(bodyKey)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('common.cancel'))),
              TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t(actionKey))),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _erase() async {
    if (!await _confirm('settings.privacy.delete_confirm.title', 'settings.privacy.delete_confirm.body', 'common.continue')) return;
    if (!mounted) return;
    if (!await _confirm('settings.privacy.delete_confirm2.title', 'settings.privacy.delete_confirm2.body', 'settings.privacy.delete_confirm2.action')) return;
    if (!mounted) return;
    final copy = ref.read(copyProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    await ref.read(dataServiceProvider).eraseAll();
    await ref.read(notificationServiceProvider).cancelAll();
    await const SecureWindow().set(false);
    // Back to a fresh-install state; the router sends the user to onboarding.
    ref.read(catNameProvider.notifier).set('');
    ref.read(dayStartHourProvider.notifier).set(4);
    ref.read(themeModeProvider.notifier).reset();
    ref.read(lowMoodSessionProvider.notifier).reset();
    ref.read(onboardingResumedProvider.notifier).reset();
    await ref.read(entitlementRepositoryProvider)?.load();
    ref.read(onboardingCompletedProvider.notifier).set(false);
    messenger.showSnackBar(SnackBar(content: Text(copy.t('settings.privacy.deleted'))));
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final db = ref.read(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('settings.privacy.title'))),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text(copy.t('settings.privacy.body')),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          title: Text(copy.t('settings.analytics_opt_out')),
          value: !_analyticsOff,
          onChanged: (on) async {
            setState(() => _analyticsOff = !on);
            await db.setSetting('analytics_opt_out', '${!on}');
          },
        ),
        SwitchListTile(
          title: Text(copy.t('settings.hide_recents')),
          subtitle: Text(copy.t('settings.hide_recents.hint')),
          value: _hideRecents,
          onChanged: (on) async {
            setState(() => _hideRecents = on);
            await db.setSetting('hide_recents', '$on');
            await const SecureWindow().set(on);
          },
        ),
        ListTile(leading: const Icon(Icons.ios_share), title: Text(copy.t('settings.export')), onTap: _busy ? null : _export),
        ListTile(
          leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          title: Text(copy.t('settings.delete_all')),
          onTap: _busy ? null : _erase,
        ),
      ]),
    );
  }
}

/// `/settings/about`.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('settings.about'))),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(copy.t('disclaimer.about')),
          const SizedBox(height: AppSpacing.md),
          Text(toPersianDigits(ref.watch(appVersionProvider)), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
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
