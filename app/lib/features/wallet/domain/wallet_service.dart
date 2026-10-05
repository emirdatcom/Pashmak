import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/time/clock.dart';

enum Currency { energy, coins }

class WalletBalance {
  const WalletBalance({required this.energy, required this.coins});
  final int energy;
  final int coins;
}

/// Energy and coins. The `wallet_ledger` is the source of truth (unique reason+ref_id makes every
/// grant idempotent); the `wallet` row is a cache of the ledger sum (docs/30 §3).
class WalletService {
  WalletService(this._db, this._clock, {required this.energyCap});

  final AppDatabase _db;
  final Clock _clock;
  final int Function() energyCap;

  Stream<WalletBalance> watch() => _db.select(_db.wallet).watchSingle().map((w) => WalletBalance(energy: w.energy, coins: w.coins));

  Future<WalletBalance> balance() async {
    final w = await _db.select(_db.wallet).getSingle();
    return WalletBalance(energy: w.energy, coins: w.coins);
  }

  /// Adds [delta] (>0). Returns the delta actually applied (energy is capped), or null if this
  /// (reason, refId) was already granted.
  Future<int?> grant(Currency currency, int delta, String reason, String refId) {
    assert(delta >= 0);
    return _db.transaction(() => _apply(currency, delta, reason, refId));
  }

  /// Subtracts [amount] if the balance allows it. Returns false when funds are insufficient or the
  /// (reason, refId) was already spent.
  Future<bool> spend(Currency currency, int amount, String reason, String refId) {
    return _db.transaction(() async {
      final bal = await balance();
      final have = currency == Currency.energy ? bal.energy : bal.coins;
      if (have < amount) return false;
      return (await _apply(currency, -amount, reason, refId)) != null;
    });
  }

  /// Undo support (docs/30 §4): reverses an earlier grant with an `adjust` entry only if the balance
  /// still covers it; otherwise nothing happens (no punishment). Returns whether it reversed.
  Future<bool> reverse(String reason, String refId) {
    return _db.transaction(() async {
      final orig = await (_db.select(_db.walletLedger)..where((t) => t.reason.equals(reason) & t.refId.equals(refId))).getSingleOrNull();
      if (orig == null || orig.delta <= 0) return false;
      final bal = await balance();
      final have = orig.currency == 'energy' ? bal.energy : bal.coins;
      if (have < orig.delta) return false;
      final cur = orig.currency == 'energy' ? Currency.energy : Currency.coins;
      return (await _apply(cur, -orig.delta, 'adjust', 'undo:${orig.id}')) != null;
    });
  }

  Future<int?> _apply(Currency currency, int delta, String reason, String refId) async {
    final dup = await (_db.select(_db.walletLedger)..where((t) => t.reason.equals(reason) & t.refId.equals(refId))).getSingleOrNull();
    if (dup != null) return null;
    final w = await _db.select(_db.wallet).getSingle();
    var applied = delta;
    if (currency == Currency.energy && delta > 0) {
      final room = (energyCap() - w.energy).clamp(0, energyCap());
      applied = delta > room ? room : delta;
    }
    final now = _clock.now().millisecondsSinceEpoch;
    await _db.into(_db.walletLedger).insert(WalletLedgerCompanion.insert(
        id: const Uuid().v4(), currency: currency.name, delta: applied, reason: reason, refId: refId, createdAt: now));
    await _db.update(_db.wallet).write(WalletCompanion(
      energy: currency == Currency.energy ? Value(w.energy + applied) : const Value.absent(),
      coins: currency == Currency.coins ? Value(w.coins + applied) : const Value.absent(),
      updatedAt: Value(now),
    ));
    return applied;
  }

  /// Recomputes the cache from the ledger (repair tool / consistency check).
  Future<void> rebuildCache() async {
    final rows = await _db.select(_db.walletLedger).get();
    var e = 0, c = 0;
    for (final r in rows) {
      if (r.currency == 'energy') {
        e += r.delta;
      } else {
        c += r.delta;
      }
    }
    await _db.update(_db.wallet).write(WalletCompanion(energy: Value(e), coins: Value(c), updatedAt: Value(_clock.now().millisecondsSinceEpoch)));
  }
}
