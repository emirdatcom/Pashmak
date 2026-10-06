import 'dart:async';

import '../../core/analytics/analytics_event.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/auth/token_store.dart';
import '../../core/l10n/digits.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';

class OtpChallenge {
  const OtpChallenge(this.id, this.retryAfterSeconds);
  final String id;
  final int retryAfterSeconds;
}

/// A failure the UI can word kindly (copy key `account.error.<reason>`).
enum PhoneLinkFailure { phoneInvalid, rateLimited, smsUnavailable, otpInvalid, otpExpired, offline, other }

class PhoneLinkException implements Exception {
  const PhoneLinkException(this.failure);
  final PhoneLinkFailure failure;
  @override
  String toString() => 'PhoneLinkException($failure)';
}

PhoneLinkFailure _map(ApiError e) => switch (e.code) {
      'PHONE_INVALID' || 'INVALID_INPUT' => PhoneLinkFailure.phoneInvalid,
      'RATE_LIMITED' => PhoneLinkFailure.rateLimited,
      'SMS_UNAVAILABLE' => PhoneLinkFailure.smsUnavailable,
      'OTP_INVALID' => PhoneLinkFailure.otpInvalid,
      'OTP_EXPIRED' => PhoneLinkFailure.otpExpired,
      'NETWORK' => PhoneLinkFailure.offline,
      _ => PhoneLinkFailure.other,
    };

/// Optional phone linking (docs/10 §6): the number only exists to bring the account back on a new phone.
class PhoneLinkService {
  PhoneLinkService(this._api, this._tokens, this._analytics, {this.onMerged});
  final ApiClient _api;
  final TokenStore _tokens;
  final AnalyticsService _analytics;

  /// Runs once the device has moved to the phone's existing account.
  final Future<void> Function()? onMerged;

  /// Persian/Arabic digits accepted; returns the Latin digits, or null when it cannot be an Iranian mobile number
  /// (the server normalises and has the final word).
  static String? cleanPhone(String input) {
    final d = normalizeDigits(input).replaceAll(RegExp(r'[\s\-()‌‎‏]'), '');
    return RegExp(r'^(\+98|0098|98|0)?9\d{9}$').hasMatch(d) ? d : null;
  }

  /// OTP codes are 5 digits; Persian digits accepted.
  static String? cleanCode(String input) {
    final d = normalizeDigits(input).replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^\d{5}$').hasMatch(d) ? d : null;
  }

  Future<OtpChallenge> requestOtp(String phone) async {
    final clean = cleanPhone(phone);
    if (clean == null) throw const PhoneLinkException(PhoneLinkFailure.phoneInvalid);
    try {
      final r = await _api.request<Map<String, dynamic>>('POST', '/v1/auth/phone/otp', data: {'phone': clean});
      return OtpChallenge(r.data!['challenge_id'] as String, r.data!['retry_after_s'] as int);
    } on ApiError catch (e) {
      throw PhoneLinkException(_map(e));
    }
  }

  /// Returns `merged`: the phone already belonged to another account and this device moved to it,
  /// so the caller should offer restoring that account's backup.
  Future<bool> verify(String challengeId, String code) async {
    final clean = cleanCode(code);
    if (clean == null) throw const PhoneLinkException(PhoneLinkFailure.otpInvalid);
    try {
      final r = await _api.request<Map<String, dynamic>>('POST', '/v1/auth/phone/verify', data: {'challenge_id': challengeId, 'code': clean});
      final d = r.data!;
      await _tokens.write(Tokens(
        access: d['access_token'] as String,
        accessExpiresAt: DateTime.parse(d['access_expires_at'] as String),
        refresh: d['refresh_token'] as String,
        userId: d['user_id'] as String,
      ));
      final merged = d['merged'] as bool;
      if (merged) await onMerged?.call();
      unawaited(_analytics.track(AnalyticsEvent.phoneLinked, {'merged': merged}));
      return merged;
    } on ApiError catch (e) {
      throw PhoneLinkException(_map(e));
    }
  }
}
