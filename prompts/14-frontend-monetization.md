# پرامپت 14 — پی‌وال، خرید، تریال، Entitlement (کلاینت)

## هدف
لایه درآمد کلاینت را بساز: `PaymentGateway` واقعی برای کافه‌بازار و مایکت (یکی per flavor)، `EntitlementRepository` با اعتبارسنجی امضای Ed25519 و منطق آفلاین/grace/pending، جریان تریال (شامل حالت آفلاین موقت)، پی‌وال config-driven با قوانین زمان نمایش، خرید/restore/consume از طریق outbox، و خرید سکه.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/60-monetization-and-entitlements.md` (کامل)؛ `docs/10-architecture-backend.md` §۶ (entitlements، trial، purchases، `EntitlementState` و الگوریتم canonical در §۶.۲)، §۸؛ `docs/20-architecture-frontend.md` §۱۰؛ `docs/30-data-and-sync.md` §۳ (`entitlement_cache`, `outbox`)، §۹؛ `docs/70-analytics-and-experiments.md` §۳، §۶؛ `docs/open-questions.md` (V2، V3، V4، A3، A17، A20).
- فاز قبلی: 10، 11. سرور: 03 (یا mock مطابق قرارداد).

## دامنه دقیق
**بساز:**
1. **Spike و تصمیم SDK (اول این کار):** مستندات رسمی فعلی Poolakey (کافه‌بازار) و Myket IAB را بررسی کن: پشتیبانی اشتراک، تریال، پلاگین Flutter نگهداری‌شده. یافته‌ها را در `docs/open-questions.md` (V2–V4) بنویس. اگر پلاگین معتبر نبود ← `MethodChannel` با کد Kotlin در `android/app/src/{bazaar,myket}/`.
2. `core/payments/`: `BazaarGateway`, `MyketGateway` (پیاده‌سازی interface سند ۲۰ §۱۰)، انتخاب در DI بر اساس flavor؛ `FakeGateway` برای dev (`--dart-define=FAKE_BILLING=true`).
3. `core/entitlement/`:
   - `SignatureVerifier`: canonical JSON دقیقاً مطابق سند ۱۰ §۶.۲ + Ed25519 (`cryptography` یا `pinenacl` — سبک‌ترین را انتخاب کن)؛ کلیدهای عمومی از `assets/keys/entitlement_pub.json` با `kid`.
   - `EntitlementRepository`: fetch `GET /v1/entitlements` (باز شدن اپ حداکثر هر ۶ ساعت، بعد از خرید/restore، نزدیک `ends_at`)، cache در `entitlement_cache`، `isPremium(now)` طبق شبه‌کد سند ۶۰ §۶ (drift ساعت، grace، `pending_verification_until`).
   - `premiumProvider` (جایگزین stub در 11).
4. **تریال:** `StartTrial` ← اگر آنلاین `POST /v1/trial/start`؛ اگر آفلاین ← تریال موقت محلی (`provisional_started_at` در `app_meta` + premium محلی تا ۷ روز) + outbox `trial_start`. پاسخ `TRIAL_ALREADY_USED` ← پیام مهربان، premium تا پایان همان روز محلی حفظ و سپس رایگان. بنر روز ۶ در خانه. صفحه آرام پایان تریال.
5. **پی‌وال** (`features/paywall`): route `/paywall?trigger=`؛ چیدمان بر اساس `paywall.variant` (حداقل دو variant: `a` فهرست عمودی، `b` کارت‌های افقی)؛ پلن‌ها از `pricing.plans` به ترتیب؛ قیمت از `PaymentGateway.products()` اگر موجود، وگرنه `display_price_toman`؛ «٪ صرفه‌جویی» نسبت به `pricing.monthly_anchor_product`؛ مزایا از copy؛ دکمه بستن واضح، «بازگردانی خرید»، لینک شرایط/حریم خصوصی. `paywall.cooldown_hours` برای نمایش خودکار. **قوانین ممنوعیت** سند ۶۰ §۵ را در `PaywallPolicy` (domain، خالص) پیاده کن و `PremiumGate` (11) را به آن وصل کن.
6. **خرید:** جریان سند ۶۰ §۶ (sequence): `purchase(sku)` ← outbox `purchase_verify` + `pending_verification_until = now + entitlement.pending_verification_hours` ← `POST /v1/purchases/verify` ← cache ← consume (فقط بعد از موفقیت سرور برای pass/coins). خطاها: لغو کاربر (بی‌صدا)، خطای مارکت (پیام «پولی کم نشده»)، `PURCHASE_INVALID` (پیام + تماس با ما)، `MARKET_UNAVAILABLE` (pending + retry).
7. **Restore:** دکمه در پی‌وال و تنظیمات ← `restore()` ← `POST /v1/purchases/restore`؛ `PURCHASE_ALREADY_CLAIMED` ← راهنمای پشتیبانی.
8. **سکه:** بسته‌های `coins_*` در فروشگاه (12) ← verify ← `wallet_ledger(reason=iap_coins, ref_id=purchase_id)` idempotent.
9. **انقضا:** وقتی premium → رایگان و عادت فعال > `limits.free_active_habits` ← صفحه انتخاب «کدوم ۳ تا فعال بمونن؟» ← بقیه `is_locked=true` (خواندنی، بدون تیک). خرید دوباره ← unlock همه.
10. صفحه «اشتراک من» در تنظیمات: وضعیت، تاریخ پایان (شمسی)، منبع، لینک مدیریت اشتراک در مارکت (اگر مارکت پشتیبانی کند).
11. آنالیتیکس: `paywall_viewed{trigger, variant}`, `paywall_plan_selected`, `paywall_closed`, `trial_started{provisional}`, `trial_ended{converted}`, `purchase_started`, `purchase_completed`, `purchase_failed{reason}`, `restore_completed`.

**نساز:** درگاه پرداخت خارج از مارکت، تبلیغ، اشتراک خانوادگی.

## ساختار فایل‌ها
```
lib/core/payments/{payment_gateway.dart, bazaar_gateway.dart, myket_gateway.dart, fake_gateway.dart, models.dart}
lib/core/entitlement/{entitlement_repository.dart, signature_verifier.dart, canonical_json.dart, premium_provider.dart}
lib/features/paywall/{domain/paywall_policy.dart, domain/start_trial.dart, domain/purchase_plan.dart, presentation/paywall_screen.dart, presentation/variants/, presentation/trial_end_screen.dart, presentation/lock_selection_screen.dart}
lib/features/settings/presentation/subscription_screen.dart
android/app/src/{bazaar,myket}/  (manifest، کد بومی در صورت نیاز)
assets/keys/entitlement_pub.json
```

## قراردادها
- API و خطاها: سند ۱۰ §۶.۱ و §۶.۳؛ `EntitlementState`: §۶.۲.
- `product_id`ها: `premium_1m`, `premium_3m`, `premium_6m`, `premium_12m`, `coins_small`, `coins_medium`.
- کلیدهای config: `pricing.*`, `trial.*`, `paywall.*`, `entitlement.*`, `limits.free_active_habits`.
- triggerهای پی‌وال: `fourth_habit`, `custom_habit`, `premium_exercise`, `premium_location`, `premium_item`, `stats_deep`, `trial_end`, `settings`.

## قوانین کدنویسی
00 §۲. هیچ تصمیم premium خارج از `EntitlementRepository`. هیچ `purchase_token` در لاگ.

## معیار پذیرش
- [ ] تست cross-language: `EntitlementState` امضاشده توسط سرور (fixture از 03) در Dart verify می‌شود؛ تغییر یک بایت ← رد.
- [ ] آفلاین با cache معتبر ← premium؛ بعد از `valid_until` و grace ← رایگان.
- [ ] خرید با `FakeGateway` و سرور mock ← premium؛ قطع شبکه بعد از پرداخت ← premium موقت ۷۲h + verify خودکار با بازگشت شبکه.
- [ ] تریال آفلاین در آنبوردینگ ← premium؛ اتصال بعدی ← تأیید سرور با `provisional_started_at`.
- [ ] پی‌وال خودکار بعد از چک‌این با `mood_level ≤ 2` یا در صفحه ایمنی/تمرین نمایش داده نمی‌شود (تست `PaywallPolicy`).
- [ ] انقضا با ۵ عادت ← صفحه انتخاب؛ ۲ عادت قفل؛ داده‌ها حفظ.
- [ ] خرید سکه دوباره verify شود ← سکه دوبار اضافه نمی‌شود.
- [ ] هر flavor فقط SDK مارکت خودش را دارد (بررسی APK).

## تست‌های لازم
- Unit: `SignatureVerifier`/canonical (golden مشترک با Go)، `isPremium` (جدول زمان/grace/pending/drift)، `PaywallPolicy`، `StartTrial` آنلاین/آفلاین، outbox handlerهای خرید.
- Widget: پی‌وال هر دو variant (golden RTL، قیمت با ارقام فارسی).
- Integration: جریان خرید و restore با `FakeGateway` + mock server.
- دستی: خرید واقعی کم‌مبلغ در هر مارکت قبل از انتشار (20).

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها + یافته‌های spike در open-questions. **گام بعد:** 15.
