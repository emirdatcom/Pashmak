import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../network/api_client.dart';
import '../network/api_error.dart';
import '../time/clock.dart';
import 'signature_verifier.dart';

class EntitlementEntry {
  const EntitlementEntry({required this.key, required this.source, required this.startsAt, required this.endsAt});
  final String key;
  final String source; // trial | subscription | pass | promo
  final DateTime startsAt;
  final DateTime endsAt;
}

/// The signed server state, parsed. Only ever built from a state whose signature verified.
class EntitlementState {
  EntitlementState(this.raw)
      : entries = [
          for (final e in (raw['entitlements'] as List).cast<Map<String, dynamic>>())
            EntitlementEntry(
                key: e['key'] as String, source: e['source'] as String, startsAt: DateTime.parse(e['starts_at'] as String), endsAt: DateTime.parse(e['ends_at'] as String)),
        ],
        serverTime = DateTime.parse(raw['server_time'] as String),
        validUntil = DateTime.parse(raw['valid_until'] as String),
        graceDays = raw['grace_days'] as int,
        trialEligible = (raw['trial'] as Map)['eligible'] as bool,
        trialUsed = (raw['trial'] as Map)['used'] as bool,
        trialEndsAt = (raw['trial'] as Map)['ends_at'] == null ? null : DateTime.parse((raw['trial'] as Map)['ends_at'] as String);

  final Map<String, dynamic> raw;
  final List<EntitlementEntry> entries;
  final DateTime serverTime;
  final DateTime validUntil;
  final int graceDays;
  final bool trialEligible;
  final bool trialUsed;
  final DateTime? trialEndsAt;
}

class EntitlementSnapshot {
  const EntitlementSnapshot({this.state, this.fetchedAt, this.drift = Duration.zero, this.pendingUntil, this.provisionalTrialStart, this.trialDays = 7, this.trialUsedUntil});
  final EntitlementState? state;
  final DateTime? fetchedAt;

  /// `server_time - device time at fetch`; corrects a wrong device clock (docs/60 §7).
  final Duration drift;

  /// `pending_verification_until`: provisional premium after a paid purchase that the server has not verified yet.
  final DateTime? pendingUntil;

  /// Offline trial started locally and not yet confirmed by the server.
  final DateTime? provisionalTrialStart;
  final int trialDays;

  /// The server refused a provisional trial (already used on this device): premium is kept until this instant.
  final DateTime? trialUsedUntil;
}

class PremiumStatus {
  const PremiumStatus({required this.isPremium, this.source, this.endsAt, this.provisional = false, this.inGrace = false});
  static const free = PremiumStatus(isPremium: false);
  final bool isPremium;
  final String? source; // trial | subscription | pass | promo | pending
  final DateTime? endsAt;
  final bool provisional; // pending verification / unconfirmed trial
  final bool inGrace;
}

/// The single decision point for "is the user premium" (docs/60 §6). Pure function of the cached
/// signed state, the pending flags and the (drift-corrected) clock.
PremiumStatus evaluatePremium(EntitlementSnapshot s, DateTime now) {
  final st = s.state;
  if (st != null) {
    final c = now.add(s.drift);
    final grace = Duration(days: st.graceDays);
    if (c.isBefore(st.validUntil)) {
      final active = st.entries.where((e) => !e.startsAt.isAfter(c) && c.isBefore(e.endsAt)).toList();
      if (active.isNotEmpty) {
        active.sort((a, b) => b.endsAt.compareTo(a.endsAt));
        return PremiumStatus(isPremium: true, source: active.first.source, endsAt: st.entries.map((e) => e.endsAt).reduce((a, b) => a.isAfter(b) ? a : b));
      }
    } else if (st.entries.isNotEmpty && c.isBefore(st.validUntil.add(grace))) {
      // Offline (or the market did not answer) around the end of the validity window: gentle grace.
      final last = st.entries.map((e) => e.endsAt).reduce((a, b) => a.isAfter(b) ? a : b);
      return PremiumStatus(isPremium: true, source: 'grace', endsAt: last, inGrace: true);
    }
  }
  final p = s.pendingUntil;
  if (p != null && now.isBefore(p)) return const PremiumStatus(isPremium: true, source: 'pending', provisional: true);
  final t = s.provisionalTrialStart;
  if (t != null && now.isBefore(t.add(Duration(days: s.trialDays)))) {
    return PremiumStatus(isPremium: true, source: 'trial', endsAt: t.add(Duration(days: s.trialDays)), provisional: true);
  }
  final used = s.trialUsedUntil;
  if (used != null && now.isBefore(used)) return PremiumStatus(isPremium: true, source: 'trial', endsAt: used, provisional: true);
  return PremiumStatus.free;
}

/// Entitlement cache + refresh. Never trusts an unsigned or wrongly signed state.
class EntitlementRepository {
  EntitlementRepository(this._db, this._api, this._verifier, this._clock, {required this.trialDays});

  final AppDatabase _db;
  final ApiClient _api;
  final SignatureVerifier _verifier;
  final Clock _clock;
  final int Function() trialDays;

  static const refreshInterval = Duration(hours: 6);
  static const _kDrift = 'ent_drift_ms';
  static const _kProvisional = 'provisional_trial_started_at';
  static const _kTrialUsedUntil = 'trial_used_until';

  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  EntitlementSnapshot _snapshot = const EntitlementSnapshot();
  EntitlementSnapshot get snapshot => _snapshot;

  PremiumStatus status([DateTime? at]) => evaluatePremium(_snapshot, at ?? _clock.now());

  Future<void> load() async {
    final row = await (_db.select(_db.entitlementCache)..where((r) => r.id.equals(1))).getSingleOrNull();
    EntitlementState? state;
    if (row != null) {
      try {
        final raw = jsonDecode(row.stateJson) as Map<String, dynamic>;
        if (_verifier.verify(raw)) state = EntitlementState(raw); // invalid signature = as if there were no cache
      } catch (_) {}
    }
    int? ms(String? v) => v == null ? null : int.tryParse(v);
    DateTime? dt(int? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
    _snapshot = EntitlementSnapshot(
      state: state,
      fetchedAt: dt(row?.fetchedAt),
      drift: Duration(milliseconds: ms(await _db.meta(_kDrift)) ?? 0),
      pendingUntil: dt(row?.pendingVerificationUntil),
      provisionalTrialStart: dt(ms(await _db.meta(_kProvisional))),
      trialDays: trialDays(),
      trialUsedUntil: dt(ms(await _db.meta(_kTrialUsedUntil))),
    );
    _changes.add(null);
  }

  /// Verifies and stores a state returned by `/entitlements`, `/trial/start`, `/purchases/*`.
  /// Returns false (and stores nothing) when the signature does not verify.
  Future<bool> accept(Map<String, dynamic> raw) async {
    if (!_verifier.verify(raw)) return false;
    final state = EntitlementState(raw);
    final now = _clock.now();
    final drift = state.serverTime.difference(now);
    final pending = _snapshot.pendingUntil;
    await _db.into(_db.entitlementCache).insertOnConflictUpdate(EntitlementCacheCompanion.insert(
          id: const Value(1),
          stateJson: jsonEncode(raw),
          signature: raw['signature'] as String,
          kid: raw['kid'] as String,
          fetchedAt: now.millisecondsSinceEpoch,
          pendingVerificationUntil: Value(pending?.millisecondsSinceEpoch),
        ));
    await _db.setMeta(_kDrift, '${drift.inMilliseconds}');
    // A confirmed trial replaces the local provisional one.
    if (state.trialEndsAt != null) await _db.setMeta('trial_started_at', '${(state.trialEndsAt!.subtract(Duration(days: trialDays()))).millisecondsSinceEpoch}');
    if (state.trialEndsAt != null) await _db.setMeta('trial_ends_at', '${state.trialEndsAt!.millisecondsSinceEpoch}');
    await _db.setMeta('premium_purchased', '${state.entries.any((e) => e.source == 'pass' || e.source == 'subscription')}');
    if (state.trialEndsAt != null) await (_db.delete(_db.appMeta)..where((t) => t.key.equals(_kProvisional))).go();
    await load();
    return true;
  }

  /// Refreshes at most every 6 hours (or when [force]); network errors keep the cache.
  Future<bool> refresh({bool force = false}) async {
    final f = _snapshot.fetchedAt;
    if (!force && f != null && _clock.now().difference(f) < refreshInterval) return false;
    try {
      final r = await _api.request<Map<String, dynamic>>('GET', '/v1/entitlements');
      return await accept(r.data!);
    } on ApiError {
      return false;
    }
  }

  /// Provisional premium after a successful market payment until the server verifies it.
  Future<void> setPending(Duration d) async {
    final until = _clock.now().add(d).millisecondsSinceEpoch;
    await _db.customStatement(
        "INSERT INTO entitlement_cache (id, state_json, signature, kid, fetched_at, pending_verification_until) VALUES (1, '', '', '', 0, ?) "
        'ON CONFLICT(id) DO UPDATE SET pending_verification_until = excluded.pending_verification_until',
        [until]);
    await load();
  }

  Future<void> clearPending() async {
    await _db.customStatement('UPDATE entitlement_cache SET pending_verification_until = NULL WHERE id = 1');
    await load();
  }

  /// Offline trial: premium locally until the outbox confirms it with the server.
  Future<DateTime> startProvisionalTrial() async {
    final now = _clock.now();
    await _db.setMeta(_kProvisional, '${now.millisecondsSinceEpoch}');
    await _db.setMeta('trial_started_at', '${now.millisecondsSinceEpoch}');
    await _db.setMeta('trial_ends_at', '${now.add(Duration(days: trialDays())).millisecondsSinceEpoch}');
    await load();
    return now;
  }

  /// The server said the trial was already used on this device: keep premium until the end of today.
  Future<void> markTrialUsed(DateTime endOfLocalDay) async {
    await _db.setMeta(_kTrialUsedUntil, '${endOfLocalDay.millisecondsSinceEpoch}');
    await _db.setMeta(_kProvisional, '');
    await load();
  }

  DateTime? get provisionalTrialStart => _snapshot.provisionalTrialStart;

  Future<void> dispose() => _changes.close();
}
