import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_event.dart';
import '../../../core/background/support_poll_task.dart';
import '../../../core/db/app_database.dart';
import '../../../core/l10n/digits.dart';
import '../../../core/l10n/jalali_formatter.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/local_day.dart';
import '../../monetization/monetization_providers.dart';
import '../data/support_socket.dart';
import '../domain/support_models.dart';
import '../support_providers.dart';

/// `/support`: the in-app chat with the support team. Text only, up to `support.max_message_chars`.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key, this.source = 'settings'});
  final String source;
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> with WidgetsBindingObserver {
  final _text = TextEditingController();
  bool _deviceMeta = false;
  bool _sending = false;
  String? _error;
  SupportSocket? _socket;
  StreamSubscription<SocketEvent>? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!ref.read(supportEnabledProvider)) return; // kill switch: no requests, no socket
    unawaited(ref.read(analyticsProvider).track(AnalyticsEvent.supportOpened, {'source': widget.source}));
    await _sync('ws');
    final socket = ref.read(supportSocketFactoryProvider)(() => _sync('poll'));
    _socket = socket;
    _events = socket.events.listen((_) => _sync('ws'));
    socket.start();
    if (ref.read(entitlementRepositoryProvider) != null) {
      unawaited(ref.read(outboxWorkerProvider).runDue()); // unsent messages from an earlier offline session
    }
  }

  Future<void> _sync(String via) async {
    final repo = ref.read(supportRepositoryProvider);
    try {
      await repo.sync(via: via);
      await repo.markAllRead();
    } catch (_) {
      // offline: the cache is shown as is
    }
    if (mounted) ref.invalidate(supportInfoProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The socket only lives while the chat is in the foreground (battery, docs/21 B6).
    if (state == AppLifecycleState.resumed) {
      _socket?.start();
      unawaited(_sync('ws'));
    } else if (state == AppLifecycleState.paused) {
      unawaited(_socket?.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    unawaited(_socket?.dispose());
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    final copy = ref.read(copyProvider);
    setState(() {
      _sending = true;
      _error = null;
    });
    _text.clear();
    final r = await ref.read(supportRepositoryProvider).send(body, includeDeviceMeta: _deviceMeta);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = switch (r.failure) {
        null => null,
        SupportFailure.disabled => copy.t('support.error.disabled'),
        SupportFailure.rateLimited => copy.t('support.error.rate_limited'),
        SupportFailure.tooLong => copy.t('support.error.too_long'),
        SupportFailure.offline => copy.t('support.error.offline'),
        SupportFailure.other => copy.t('support.error.other'),
      };
    });
    // From now on poll for the reply in the background (no push service, decision D-9).
    unawaited(scheduleSupportPoll(ref.read(supportPollScheduleProvider).firstInterval));
  }

  Future<void> _delete() async {
    final copy = ref.read(copyProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(copy.t('support.delete.confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t('support.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(supportRepositoryProvider).deleteConversation();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('support.deleted'))));
    } catch (_) {
      if (mounted) setState(() => _error = copy.t('support.error.offline'));
    }
  }

  String _nextOnline(DateTime t) {
    final l = t.toLocal();
    final day = LocalDay.fromDate(l);
    final hh = l.hour.toString().padLeft(2, '0');
    final mm = l.minute.toString().padLeft(2, '0');
    return toPersianDigits('${JalaliFormatter.weekday(day)} $hh:$mm');
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    final enabled = ref.watch(supportEnabledProvider);
    final info = ref.watch(supportInfoProvider).value;
    final messages = ref.watch(supportMessagesProvider).value ?? const <SupportMessagesCacheData>[];
    final maxChars = ref.watch(appConfigProvider).supportMaxMessageChars;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('support.title')),
        actions: [IconButton(tooltip: copy.t('support.delete'), icon: const Icon(Icons.delete_outline), onPressed: messages.isEmpty ? null : _delete)],
      ),
      body: !enabled
          ? Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(copy.t('support.unavailable'), textAlign: TextAlign.center)))
          : Column(children: [
              if (info != null && !info.online && info.nextOnlineAt != null)
                _Banner(text: copy.t('support.offline_hours', {'time': _nextOnline(info.nextOnlineAt!)})),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(copy.t('support.note'), style: theme.textTheme.bodySmall),
                  TextButton(onPressed: () => context.push(Routes.safety), child: Text(copy.t('support.help_link'))),
                ]),
              ),
              Expanded(
                child: messages.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(copy.t('support.empty'), textAlign: TextAlign.center)))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: messages.length,
                        itemBuilder: (c, i) => _Bubble(message: messages[messages.length - 1 - i], onRetry: (id) => ref.read(supportRepositoryProvider).retry(id)),
                      ),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _deviceMeta,
                onChanged: (v) => setState(() => _deviceMeta = v ?? false),
                title: Text(copy.t('support.device_meta')),
                subtitle: Text(copy.t('support.device_meta.hint')),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: maxChars,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(hintText: copy.t('support.hint'), counterText: ''),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(tooltip: copy.t('support.send'), icon: const Icon(Icons.send), onPressed: _sending ? null : _send),
                  ]),
                ),
              ),
            ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.creamDeep,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(text, textAlign: TextAlign.center),
      );
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.onRetry});
  final SupportMessagesCacheData message;
  final void Function(String id) onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = ref.watch(copyProvider);
    final mine = message.sender == 'user';
    final scheme = Theme.of(context).colorScheme;
    final time = DateTime.fromMillisecondsSinceEpoch(message.createdAt);
    final stamp = toPersianDigits('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
    final status = mine ? copy.t('support.status.${message.status}') : (message.operatorName ?? '');
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Semantics(
        label: '${mine ? '' : '${message.operatorName ?? ''}: '}${message.body}',
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          decoration: BoxDecoration(color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(toPersianDigitsInText(message.body)),
            const SizedBox(height: 2),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('$stamp${status.isEmpty ? '' : ' · $status'}', style: Theme.of(context).textTheme.bodySmall),
              if (mine && message.status == 'failed') TextButton(onPressed: () => onRetry(message.id), child: Text(copy.t('support.retry'))),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Message text is shown as typed; only the chat's own decoration uses Persian digits.
String toPersianDigitsInText(String s) => s;
