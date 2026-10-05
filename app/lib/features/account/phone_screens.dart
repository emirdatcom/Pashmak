import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/digits.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/tokens.dart';
import '../backup/backup_providers.dart';
import 'phone_link_service.dart';

/// `/settings/phone`: enter the number, then the 5-digit code (resend timer from `retry_after_s`).
class PhoneLinkScreen extends ConsumerStatefulWidget {
  const PhoneLinkScreen({super.key});
  @override
  ConsumerState<PhoneLinkScreen> createState() => _PhoneLinkState();
}

class _PhoneLinkState extends ConsumerState<PhoneLinkScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  OtpChallenge? _challenge;
  int _wait = 0;
  Timer? _timer;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String _msg(PhoneLinkFailure f) => ref.read(copyProvider).t(switch (f) {
        PhoneLinkFailure.phoneInvalid => 'account.error.phone_invalid',
        PhoneLinkFailure.rateLimited => 'account.error.rate_limited',
        PhoneLinkFailure.smsUnavailable => 'account.error.sms_unavailable',
        PhoneLinkFailure.otpInvalid => 'account.error.otp_invalid',
        PhoneLinkFailure.otpExpired => 'account.error.otp_expired',
        PhoneLinkFailure.offline => 'account.error.offline',
        PhoneLinkFailure.other => 'account.error.other',
      });

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = (_wait - 1).clamp(0, 1 << 30));
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await ref.read(phoneLinkServiceProvider).requestOtp(_phone.text);
      if (!mounted) return;
      setState(() => _challenge = c);
      _startTimer(c.retryAfterSeconds);
    } on PhoneLinkException catch (e) {
      setState(() => _error = _msg(e.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final copy = ref.read(copyProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final merged = await ref.read(phoneLinkServiceProvider).verify(_challenge!.id, _code.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.t('account.linked'))));
      if (merged) {
        final restore = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(copy.t('account.merged.title')),
            content: Text(copy.t('account.merged.body')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(copy.t('common.skip'))),
              TextButton(onPressed: () => Navigator.pop(c, true), child: Text(copy.t('backup.restore'))),
            ],
          ),
        );
        if (!mounted) return;
        if (restore == true) {
          context.pushReplacement('${Routes.settings}/restore');
          return;
        }
      }
      context.pop();
    } on PhoneLinkException catch (e) {
      setState(() => _error = _msg(e.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(copyProvider);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('account.title'))),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text(copy.t('account.intro')),
        const SizedBox(height: AppSpacing.md),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(controller: _phone, enabled: _challenge == null, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: copy.t('account.phone.hint'))),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_challenge == null)
          FilledButton(onPressed: _busy ? null : _send, child: Text(copy.t('account.send')))
        else ...[
          Text(copy.t('account.otp.title'), style: Theme.of(context).textTheme.titleMedium),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(controller: _code, maxLength: 5, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: copy.t('account.otp.hint'))),
          ),
          FilledButton(onPressed: _busy ? null : _verify, child: Text(copy.t('account.otp.verify'))),
          TextButton(
            onPressed: (_busy || _wait > 0) ? null : _send,
            child: Text(_wait > 0 ? copy.t('account.otp.wait', {'n': toPersianDigits(_wait)}) : copy.t('account.otp.resend')),
          ),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ]),
    );
  }
}
