import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../core_loop_providers.dart';
import '../backup_providers.dart';
import '../data/backup_service.dart';
import '../domain/crypto.dart';
import '../domain/snapshot.dart';
import '../domain/snapshot_upgraders.dart';

String _dateTime(DateTime d) {
  final l = d.toLocal();
  return toPersianDigits('${JalaliFormatter.date(LocalDay.fromDate(l))} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}');
}

/// `/settings/backup`: enable (code + proof), status, manual backup, delete, restore.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool? _enabled;
  DateTime? _last;
  SetupChallenge? _challenge;
  bool _confirming = false;
  bool _busy = false;
  String? _message;
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = ref.read(backupServiceProvider);
    final e = await svc.isEnabled();
    final l = await svc.lastBackupAt();
    if (!mounted) return;
    setState(() {
      _enabled = e;
      _last = l;
    });
  }

  Future<void> _backup() async {
    final copy = ref.read(copyProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await ref.read(backupServiceProvider).backupNow();
    await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = copy.t(switch (r) {
        BackupOutcome.done => 'backup.done',
        BackupOutcome.tooLarge => 'backup.too_large',
        _ => 'backup.failed',
      });
    });
  }

  Future<void> _delete() async {
    final copy = ref.read(copyProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(copy.t('backup.delete.confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t('backup.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).deleteRemote();
      _message = copy.t('backup.deleted');
    } catch (_) {
      _message = copy.t('backup.failed');
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final theme = Theme.of(context);
    Widget body;
    if (_enabled == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_challenge != null) {
      final c = _challenge!;
      body = ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        if (!_confirming) ...[
          Text(copy.t('backup.code.title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(c.code, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontFeatures: const [])),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(copy.t('backup.code.warning')),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: () => setState(() => _confirming = true), child: Text(copy.t('backup.code.continue'))),
        ] else ...[
          Text(copy.t('backup.verify.title'), style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(copy.t('backup.verify.body', {'n': toPersianDigits(c.positions.map((p) => p + 1).join(', '))})),
          const SizedBox(height: AppSpacing.md),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(controller: _typed, maxLength: 4, textCapitalization: TextCapitalization.characters, inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))]),
          ),
          if (_message != null) Text(_message!, style: TextStyle(color: theme.colorScheme.error)),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    if (!c.verify(_typed.text)) {
                      setState(() => _message = copy.t('backup.verify.wrong'));
                      return;
                    }
                    setState(() => _busy = true);
                    final svc = ref.read(backupServiceProvider);
                    await svc.enable(c);
                    final r = await svc.backupNow();
                    await _load();
                    if (!mounted) return;
                    setState(() {
                      _challenge = null;
                      _confirming = false;
                      _busy = false;
                      _typed.clear();
                      _message = copy.t(r == BackupOutcome.done ? 'backup.done' : 'backup.failed');
                    });
                  },
            child: Text(copy.t('backup.verify.confirm')),
          ),
        ],
      ]);
    } else if (!_enabled!) {
      body = ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text(copy.t('backup.intro')),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: () => setState(() => _challenge = ref.read(backupServiceProvider).beginSetup()), child: Text(copy.t('backup.enable'))),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: () => context.push('${Routes.settings}/restore'), child: Text(copy.t('backup.restore'))),
      ]);
    } else {
      body = ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text(_last == null ? copy.t('backup.never') : copy.t('backup.last', {'date': _dateTime(_last!)}), style: theme.textTheme.titleMedium),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: Text(_message!)),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(onPressed: _busy ? null : _backup, child: Text(copy.t('backup.now'))),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(onPressed: _busy ? null : () => context.push('${Routes.settings}/restore'), child: Text(copy.t('backup.restore'))),
        TextButton(onPressed: _busy ? null : _delete, child: Text(copy.t('backup.delete'))),
        if (_busy) const Center(child: CircularProgressIndicator()),
      ]);
    }
    return Scaffold(appBar: AppBar(title: Text(copy.t('backup.title'))), body: body);
  }
}

/// `/settings/restore`: fetch → recovery code → decrypt → summary → explicit confirm → full replace.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});
  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  RemoteBackup? _remote;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final copy = ref.read(copyProvider);
    try {
      final r = await ref.read(backupServiceProvider).fetchRemote();
      if (!mounted) return;
      setState(() {
        _remote = r;
        _loading = false;
        if (r == null) _error = copy.t('restore.none');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = copy.t('restore.corrupt');
      });
    }
  }

  Future<void> _check() async {
    final copy = ref.read(copyProvider);
    final svc = ref.read(backupServiceProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snap = await svc.decrypt(_remote!, _code.text);
      final sum = SnapshotImporter(ref.read(databaseProvider)).summarize(snap);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(copy.t('restore.title')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(copy.t('restore.summary', {'date': sum.exportedAt == null ? '' : _dateTime(sum.exportedAt!)})),
            Text(copy.t('restore.summary.habits', {'n': sum.habits})),
            Text(copy.t('restore.summary.checkins', {'n': sum.checkins})),
            const SizedBox(height: AppSpacing.sm),
            Text(copy.t('restore.warning')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('common.cancel'))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t('restore.confirm'))),
          ],
        ),
      );
      if (ok != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await svc.restore(snap, codeInput: _code.text);
      await ref.read(notificationSchedulerProvider).replan();
      final db = ref.read(databaseProvider);
      ref.read(catNameProvider.notifier).set(await db.meta('cat_name') ?? '');
      ref.read(onboardingCompletedProvider.notifier).set(true); // a restored account is, by definition, past onboarding
      await db.setMeta('onboarding_completed', 'true');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('restore.done'))));
      context.go(Routes.home);
    } on BackupDecryptError catch (e) {
      setState(() => _error = copy.t(e.reason == 'corrupt' ? 'restore.corrupt' : 'restore.code.wrong'));
    } on SnapshotTooNew {
      setState(() => _error = copy.t('restore.too_new'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('restore.title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
              if (_remote != null) ...[
                if (_remote!.updatedAt != null) Text(copy.t('backup.last', {'date': _dateTime(_remote!.updatedAt!)})),
                const SizedBox(height: AppSpacing.md),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: copy.t('restore.code.hint'))),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: _busy ? null : _check, child: Text(copy.t('restore.check'))),
              ],
              if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              if (_busy) const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator())),
            ]),
    );
  }
}
