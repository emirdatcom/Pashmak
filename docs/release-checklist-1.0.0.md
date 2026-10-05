# چک‌لیست انتشار 1.0.0 (MVP)

وضعیت هر ردیف صادقانه ثبت شده: ✅ در مخزن انجام و تست شده · 🟡 کد/سند آماده ولی روی محیط واقعی اجرا نشده · ⬜ انجام نشده/نیازمند انسان.

## کد و تست (در این مخزن)
- ✅ بک‌اند: تست واحد + integration روی Postgres واقعی + contract با OpenAPI (پرامپت 01–05)
- ✅ اپ: `flutter analyze` تمیز و تست‌های واحد/widget/flow/contract (`flutter test`)
- ✅ fixture امضاشده‌ی مشترک Go↔Dart (`fixtures/entitlement_state_signed.json`)
- ✅ هم‌خوانی `events.json` ↔ enum Dart ↔ allowlist Go (`gen_analytics_events.dart --check` در CI)
- ✅ هم‌خوانی `default.json` ↔ getterهای `AppConfig` و فراخوانی‌های اپ ↔ OpenAPI (`test/contract_test.dart`)
- ✅ content-lint سبز
- ✅ ارسال رویدادها به `/v1/events` با تست (صف، retry، حذف دسته‌ی نامعتبر)

## محیط و زیرساخت
- 🟡 staging: `backend/deploy/docker-compose.staging.yml` + `.env.staging.example` (اجرا نشده)
- 🟡 تست بار k6: `load/k6/*.js` (اجرا نشده؛ هدف 200rps، p95<200ms، خطا<0.5٪)
- 🟡 smoke: `scripts/smoke.sh <url>`
- ⬜ VPS production، فایروال، TLS، DNS
- ⬜ کلیدهای Ed25519 تولید و کلید عمومی در `app/assets/keys/entitlement_pub.json` (فعلاً خالی ⇒ همه رایگان)
- ⬜ بکاپ `pg_dump` روزانه + **تست restore با ثبت زمان (RTO ≤ ۴h)**
- ⬜ هشدارها (5xx، market_verify، دیسک)

## مارکت‌ها (سند 80 §7)
- ⬜ SKUها در پنل Bazaar/Myket و تطبیق با `products.json`/`pricing.plans`
- ⬜ credential تأیید خرید سرور (Bazaar: OAuth؛ Myket: توکن) و خرید واقعی کم‌مبلغ
- ⬜ **V2/V3/V4**: کد Kotlin هر flavor با خرید واقعی آزموده شود (نوشته‌شده از روی SDKهای متن‌باز، کامپایل نشده)
- ⬜ خرید + restore + لغو/refund در هر دو مارکت
- ⬜ `applicationId`، امضا، `versionCode` یکتا per flavor، `targetSdk` طبق الزام
- ⬜ build release: `flutter build apk --release --flavor <f> -t lib/main_<f>.dart --obfuscate --split-debug-info=build/symbols --split-per-abi` و آرشیو `build/symbols`
- ⬜ اندازه‌ی APK arm64 < 15MB و شروع سرد < 2s (`docs/perf-report.md`)
- ⬜ تست روی ۳ دستگاه مرجع: آنبوردینگ، نوتیف بعد از ریبوت، خرید/restore/انقضا
- ⬜ صفحه‌ی مارکت: `docs/store-listing.md`، اسکرین‌شات، رده‌ی سنی، URL حریم خصوصی
- ⬜ `min_supported_version` در config و تست مسیر force update

## محتوا و ایمنی
- ⬜ شماره‌های خط کمک (`safety.json`) تأیید شوند (V9) **یا** پنهان بمانند (الان `verified_at=null` ⇒ نمایش داده نمی‌شوند)
- ⬜ فهرست `brand.name_blocklist` با فهرست واقعی کامل شود
- ⬜ متن «شرایط استفاده» و «حریم خصوصی» نوشته شود (`/settings/terms` هنوز placeholder)
- ✅ پشتیبانی = چت درون‌برنامه‌ای (`support_contact: in_app_chat`)
- ⬜ شماره‌های ۱۱۵/۱۲۳/۱۴۸۰ تأیید مالک و `verified_at` پر شود (V9)
- ⬜ مالک: تأیید ۱۱۵، ۱۲۳، ۱۴۸۰ و پر کردن `verified_at` در `config-data/content/safety.json` و `app/assets/content/safety.json`
- ⬜ چک دستی نشت SDK (افزودن عمدی وابستگی مارکت دیگر ← CI باید رد کند)؛ فقط self-test مصنوعی اجرا شده

## سناریوهای E2E روی staging (prompt 20 §3) — هیچ‌کدام هنوز اجرا نشده
- ⬜ نصب ← آنبوردینگ ← تریال آنلاین ← ۳ عادت ← تیک ← ماجراجویی ← claim ← خرید آیتم
- ⬜ تریال آفلاین ← اتصال ← تأیید سرور
- ⬜ خرید `premium_12m` (fake) ← premium ← refund ← رایگان + صفحه‌ی انتخاب عادت
- ⬜ تغییر سقف عادت از admin-cli ← اعمال بعد از refresh
- ⬜ انتشار content pack جدید ← متن جدید
- ⬜ بررسی `events` سرور: بدون `mood_level`/متن
- ⬜ hard force update
- ⬜ (فاز ۲) backup ← نصب تازه ← OTP ← restore
معادل دامنه‌ای بخش‌هایی از این‌ها به‌صورت تست خودکار بدون دستگاه در `app/test/e2e_flow_test.dart` و تست‌های بک‌اند اجرا می‌شود.
