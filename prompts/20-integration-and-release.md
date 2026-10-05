# پرامپت 20 — یکپارچه‌سازی، تست انتها به انتها، آماده‌سازی انتشار

## هدف
بک‌اند و اپ را واقعاً به هم وصل کن، تست‌های انتها به انتها را روی محیط staging اجرا کن، استقرار production روی سرور ایرانی را راه بینداز، و همه چیز را برای انتشار در کافه‌بازار و مایکت آماده کن. این پرامپت در پایان هر فاز (MVP، فاز ۲) دوباره اجرا می‌شود.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ همه `docs/` (به‌خصوص `10` §۱۳–§۱۵، `20` §۱۲–§۱۳، `60` §۷، `70` §۵، `80` §۶–§۸، `open-questions.md`).
- فاز قبلی: MVP: 01–04، 10–12، 13A، 14، 15. فاز ۲: + 05، 13B، 16.

## دامنه دقیق
**بساز/انجام بده:**
1. **قرارداد:** تست contract خودکار: اپ (mock-free) در برابر `api/openapi.yaml`؛ یک fixture مشترک `EntitlementState` امضاشده که هم تست Go و هم Dart از آن استفاده کنند؛ چک CI که `config-data/analytics/events.json` با enum `AnalyticsEvent` در Dart و allowlist Go هم‌خوان است؛ چک که کلیدهای `default.json` با getterهای `AppConfig` هم‌خوان است.
2. **محیط staging:** Docker Compose روی سرور staging (یا همان سرور با namespace جدا)، adapter `fake` مارکت فعال، `--dart-define=API_BASE_URL=staging` در build `staging` هر flavor.
3. **E2E (`integration_test` روی emulator/دستگاه + staging):**
   - نصب ← آنبوردینگ ← تریال (آنلاین) ← ۳ عادت ← تیک ← ماجراجویی (مدت کوتاه از config staging: ۱ دقیقه) ← claim ← خرید آیتم.
   - تریال آفلاین ← اتصال ← تأیید سرور.
   - خرید `premium_12m` با fake ← premium ← reverify refund ← رایگان + صفحه انتخاب عادت‌ها.
   - تغییر config (سقف ۵ عادت) از admin-cli ← اپ بعد از refresh سقف جدید را اعمال می‌کند.
   - انتشار content pack جدید ← متن جدید در اپ.
   - رویدادها در `events` سرور ثبت می‌شوند و **هیچ** `mood_level`/متن نیست (کوئری چک).
   - force update (hard) با `update.min_supported_version`.
   - (فاز ۲) backup ← نصب تازه ← OTP ← restore.
4. **تست بار:** k6 روی staging: `/v1/config`, `/v1/events`, `/v1/auth/device` در ۲۰۰ rps، p95 < 200ms، خطا < 0.5٪.
5. **Production:** provisioning VPS ایرانی (سند ۱۰ §۱۳)، فایروال، SSH key-only، Caddy + TLS، `.env` با secretها، کلیدهای Ed25519 (`admin-cli keygen`، کلید عمومی در `assets/keys/`)، credential مارکت‌ها، `pg_dump` روزانه به object storage + تست restore، متریک و هشدار، runbook در `docs/runbook.md` (deploy، rollback، چرخش کلید، بازیابی DB، واکنش به قطعی مارکت).
6. **انتشار:** build release هر flavor (`--obfuscate --split-debug-info`, `--split-per-abi` + universal اگر مارکت لازم داشت **[نیاز به راستی‌آزمایی]**)، امضا، آرشیو mapping، چک‌لیست کامل سند ۸۰ §۷، خرید واقعی کم‌مبلغ + restore + لغو در هر مارکت، متن‌های صفحه مارکت در `docs/store-listing.md`.
7. **پس از انتشار:** داشبورد rollup (سند ۷۰ §۵) از `/admin/v1/metrics/daily` بررسی؛ آستانه‌های هشدار crash-free و 5xx.

**نساز:** قابلیت جدید محصول.

## ساختار فایل‌ها
```
backend/test/contract/  app/integration_test/e2e_*.dart  load/k6/*.js
fixtures/entitlement_state_signed.json
docs/{runbook.md, store-listing.md, release-checklist-{version}.md, perf-report.md}
.github/workflows/{e2e.yml, release.yml}
```

## قراردادها
همه از `docs/` بدون تغییر؛ هر ناسازگاری کشف‌شده ← اول docs اصلاح، بعد کد.

## قوانین کدنویسی
00 §۲. secretها فقط در secret store CI و `.env` سرور؛ هرگز در repo.

## معیار پذیرش
- [ ] همه سناریوهای E2E بند ۳ سبز روی staging.
- [ ] تست بار با اهداف بند ۴.
- [ ] production: `/healthz` از اینترنت؛ `/metrics` و `/admin` فقط از IP مدیریت.
- [ ] restore بکاپ DB روی سرور جدا تست و زمان آن (≤ RTO ۴h) ثبت شده.
- [ ] خرید واقعی، restore و (در صورت امکان) refund در هر دو مارکت موفق.
- [ ] چک‌لیست سند ۸۰ §۷ کاملاً تیک خورده؛ شماره‌های خط کمک یا تأییدشده‌اند یا پنهان.
- [ ] `docs/open-questions.md`: هیچ مورد V مرتبط با MVP باز نمانده (یا با تصمیم صریح ریسک‌پذیری بسته شده).

## تست‌های لازم
Contract، E2E، load، smoke production (اسکریپت `scripts/smoke.sh`: health، config، content manifest).

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها + نسخه در هر دو مارکت تأیید و منتشر شده. **گام بعد:** پایش ۲ هفته‌ای متریک‌ها، سپس فاز ۲ (05، 13B، 16) و اجرای دوباره همین پرامپت.
