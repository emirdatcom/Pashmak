# پرامپت 03 — Entitlement، تریال، تأیید خرید

## هدف
منطق اشتراک سمت سرور را بساز: محصولات، تریال ۷ روزه یک‌بار per دستگاه، تأیید خرید با adapterهای کافه‌بازار و مایکت پشت یک port، grantهای دوره‌دار، صدور `EntitlementState` امضاشده با Ed25519، restore، و worker بازتأیید دوره‌ای برای تمدید/لغو/رفاند.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`، `docs/10-architecture-backend.md` §۵.۲، §۶ (entitlement/trial/purchases)، §۶.۲ (`EntitlementState`)، §۸؛ `docs/60-monetization-and-entitlements.md` (کامل)؛ `docs/open-questions.md` (A2، A3، A20، V1–V5، V12).
- فاز قبلی: 01، 02.

## دامنه دقیق
**بساز:**
1. مهاجرت `0003_entitlements.sql`: `products`, `purchases`, `entitlement_grants`, `trials` مطابق سند ۱۰ §۵.۲. ایندکس: `purchases(market, purchase_token_hash)` unique، `entitlement_grants(user_id, ends_at)`، `trials(device_hash)` unique.
2. Seed محصولات از `config-data/products.json` (`admin-cli seed-products`): `premium_1m/3m/6m/12m`, `coins_small`, `coins_medium` با `market_sku` per market.
3. ماژول `entitlement`:
   - `State(ctx, userID) EntitlementState`: grantهای فعال، وضعیت تریال (`eligible` بر اساس `device_hash` دستگاه فعلی و `trial.enabled` از config)، `server_time`, `valid_until = min(max(ends_at), server_time + entitlement.offline_validity_days)`, `grace_days`, امضا روی canonical JSON (کلیدها مرتب، بدون فاصله، بدون فیلد `signature`/`kid`)، `kid` با پیشوند `ent-`.
   - `StartTrial(ctx, userID, deviceID, provisionalStartedAt?)`: قواعد سند ۶۰ §۴ (پذیرش provisional ≤ ۴۸h)؛ grant `source=trial`؛ تکراری per `device_hash` ← `TRIAL_ALREADY_USED`.
   - `GET /v1/entitlements`، `POST /v1/trial/start`.
   - پیاده‌سازی `UserDeletionHook` (grantها باقی، ولی revoke؛ purchases برای حسابرسی باقی).
4. ماژول `billing`:
   - port `MarketVerifier` (سند ۱۰ §۸) + `MarketPurchase` struct؛ رجیستری per `market`.
   - adapter `bazaar` و `myket`: **API دقیق [نیاز به راستی‌آزمایی]**. ابتدا مستندات رسمی فعلی هر مارکت را بررسی کن؛ اگر در دسترس نبود، adapter را با interface کامل و TODO مستند بساز و پشت feature flag `BILLING_{MARKET}_ENABLED` غیرفعال کن. credentialها از env (`BAZAAR_*`, `MYKET_*`).
   - adapter `fake` (برای dev/staging): توکن‌هایی با پیشوند `test_valid_`, `test_refunded_`, `test_invalid_`.
   - `POST /v1/purchases/verify` و `POST /v1/purchases/restore` با الگوریتم سند ۱۰ §۸ (idempotent، تراکنش، timeout ۸s، retry ۲ بار، `MARKET_UNAVAILABLE`). `purchase_token` با AES-GCM (`DATA_ENC_KEY`) رمز و با sha256 hash ذخیره.
   - انباشت grant برای `pass` (سند ۶۰ §۲)؛ برای `subscription` ← `ends_at = expires_at` مارکت.
   - `consumable` ← `coins_granted` در پاسخ (بدون grant).
5. Job worker `reverify_subscriptions` (هر ۶ ساعت): خریدهای `subscription` با `expires_at` در ۴۸h آینده یا خریداری‌شده در ۷ روز اخیر؛ به‌روزرسانی state؛ refund/cancel ← `revoked_at` یا ثبت `auto_renewing=false`؛ تولید رویداد سرور `subscription_canceled` در جدول `events` (اگر ماژول analytics هنوز نیست، از طریق interface `ServerEventSink` با impl no-op).
6. متریک `market_verify_total{market,result}`.
7. OpenAPI به‌روز.

**نساز:** UI/پی‌وال (فرانت 14)، promo grant admin (در 04 همراه سایر admin endpointها؛ اینجا فقط متد service `GrantPromo` را بساز).

## ساختار فایل‌ها
```
backend/internal/modules/entitlement/{handler.go, service.go, canonical.go, trial.go, ports.go, *_test.go}
backend/internal/modules/billing/{handler.go, service.go, ports.go, registry.go}
backend/internal/modules/billing/{bazaar,myket,fake}/adapter.go
backend/cmd/worker/jobs/reverify.go
backend/db/migrations/0003_entitlements.sql
backend/db/queries/{products.sql, purchases.sql, grants.sql, trials.sql}
config-data/products.json
```

## قراردادها
- endpointها و خطاها: سند ۱۰ §۶.۱ (ردیف‌های entitlements، trial، purchases).
- `EntitlementState`: سند ۱۰ §۶.۲ (عیناً). **کلاینت (پرامپت 14) همین canonicalization را بازتولید می‌کند** — الگوریتم canonical را در `docs/10-architecture-backend.md` §۶.۲ با یک مثال ورودی/خروجی و امضای نمونه (کلید تست) مستند کن.
- کلیدهای config مصرفی: `trial.enabled`, `trial.days`, `entitlement.grace_days`, `entitlement.offline_validity_days` (خواندن از ماژول remoteconfig اگر آماده است، وگرنه interface `ConfigReader` با پیش‌فرض‌های سند ۶۰ §۳).

## قوانین کدنویسی
00 §۲. هر تغییر grant/purchase در تراکنش. هیچ توکن خرید در لاگ (فقط ۸ نویسه آخر hash).

## معیار پذیرش
- [ ] تریال: اولین درخواست ← grant ۷ روزه؛ کاربر جدید با همان `device_hash` ← `TRIAL_ALREADY_USED`.
- [ ] provisional ۲۴ ساعت قبل ← `ends_at = provisional + 7d`؛ ۷۲ ساعت قبل ← نادیده، `now + 7d`.
- [ ] verify با fake `test_valid_` برای `premium_3m` (pass) ← grant ۹۰ روزه؛ خرید دوم ← انباشت تا ۱۸۰ روز.
- [ ] همان توکن دوباره برای همان کاربر ← idempotent (همان پاسخ)؛ برای کاربر دیگر ← `PURCHASE_ALREADY_CLAIMED`.
- [ ] timeout مارکت ← `503 MARKET_UNAVAILABLE`.
- [ ] `test_refunded_` در reverify ← grant revoked؛ `GET /entitlements` دیگر premium نیست.
- [ ] امضای `EntitlementState` با کلید عمومی قابل تأیید است؛ تغییر هر بایت ← نامعتبر.
- [ ] `coins_small` ← `coins_granted` درست، بدون grant.
- [ ] fixture `fixtures/entitlement_state_signed.json` (state نمونه + امضا با کلید تست + کلید عمومی) تولید و commit شده تا 14 و 20 از آن استفاده کنند.

## تست‌های لازم
- Unit: canonical JSON (golden)، محاسبه `valid_until`، انباشت grant، قواعد تریال، state machine خرید.
- Integration: verify/restore/reverify با adapter fake روی Postgres.
- Golden adapter: پاسخ‌های JSON ضبط‌شده (یا نمونه مستند) هر مارکت ← `MarketPurchase`.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها + `docs/open-questions.md` با یافته‌های واقعی درباره API مارکت‌ها (V1–V5) به‌روز شده. **گام بعد:** 04 (اگر نشده) و سپس 20 برای یکپارچه‌سازی با فرانت 14.
