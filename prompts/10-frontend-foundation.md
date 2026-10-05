# پرامپت 10 — اسکلت Flutter

## هدف
اسکلت اپ Flutter اندروید را بساز: دو flavor (`bazaar`, `myket`)، bootstrap، تم و RTL و فونت فارسی، تقویم شمسی و ارقام فارسی، ناوبری با go_router، DI با Riverpod، دیتابیس محلی رمزنگاری‌شده با Drift و زیرساخت migration، کلاینت شبکه با refresh خودکار توکن، هویت دستگاه، outbox، Repositoryهای config و content با fallback bundled، `CopyResolver`، و interfaceهای cross-cutting (analytics، notifications، payments، cat renderer) با impl موقت. هیچ feature کاربری کامل در این مرحله ساخته نمی‌شود.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/20-architecture-frontend.md` (کامل)؛ `docs/30-data-and-sync.md` §۲–§۳، §۸، §۱۱؛ `docs/40-content-and-copy-system.md` §۲–§۳؛ `docs/10-architecture-backend.md` §۶ (قرارداد API، برای ApiClient)؛ `docs/80-quality-security-privacy.md` §۲.
- فاز قبلی: ندارد (سرور می‌تواند هنوز نباشد؛ با mock کار کن).

## دامنه دقیق
**بساز:**
1. پروژه `app/` با `applicationId` از `android/brand.properties`؛ flavorها `bazaar`, `myket` (`productFlavors`، `main_bazaar.dart`, `main_myket.dart`)؛ `minSdk 23`؛ `allowBackup=false`؛ `network_security_config` بدون cleartext؛ R8 + `shrinkResources`.
2. `bootstrap.dart`: `WidgetsFlutterBinding`، init timezone، باز کردن DB، `ProviderScope` با overrideهای flavor، `FlutterError.onError` + `PlatformDispatcher.onError` ← `AppLogger` (ذخیره محلی ۲۰۰ خطای آخر).
3. `core/theme`: tokens (رنگ‌ها: کرم، نارنجی گربه، فیروزه‌ای؛ فاصله، radius، تایپوگرافی Vazirmatn subset Regular/Bold)، `AppTheme.light`/`dark`، کنتراست AA.
4. `core/l10n`: `toPersianDigits`, `normalizeDigits` (فارسی/عربی ← لاتین)، `JalaliFormatter` (تاریخ، نام ماه، روز هفته؛ هفته از شنبه) با `shamsi_date`.
5. `core/time`: `Clock` (interface + `SystemClock` + `FakeClock`)، `LocalDay` (محاسبه با `day_start_hour` و timezone دستگاه؛ متدهای `today`, `addDays`, `weekStart`).
6. `core/db`: `AppDatabase` (drift + SQLCipher) با **همه جداول سند ۳۰ §۳** (حتی اگر featureها بعداً پر کنند)، `schemaVersion = 1`، export schema با `drift_dev` به `drift_schemas/`، کلید ۳۲ بایتی در `flutter_secure_storage`، مسیر خطای Keystore (صفحه `system/db_error`).
7. `core/auth`: `DeviceIdentity` (`install_id` UUIDv4 در `app_meta`؛ `device_hash_raw` = ANDROID_ID از platform channel کوچک)، `TokenStore` (secure storage).
8. `core/network`: `ApiClient` (dio)، baseUrl per env (`--dart-define=API_BASE_URL`)، هدرهای `X-App-Version`, `X-Market`, `X-Install-Id`, `Accept-Language: fa`؛ `AuthInterceptor` (ثبت دستگاه lazily با `POST /v1/auth/device`، refresh با قفل هم‌زمانی، retry یک‌باره)؛ نگاشت فرم خطای سند ۱۰ §۶ به `ApiError(code)`؛ timeout ۱۰s.
9. `core/outbox`: جدول `outbox` + `OutboxWorker` (handler registry per `kind`، backoff نمایی تا ۶ ساعت، اجرا روی باز شدن اپ، تغییر اتصال، WorkManager `outbox_flush` هر ۱۲ ساعت).
10. `core/config`: مدل typed `AppConfig` (getterها برای همه پیشوندهای 00 §۳ بند ۷) از `assets/config/default.json` (کپی از `config-data/config/default.json` در build با اسکریپت `tool/sync_assets.dart`) + override از `GET /v1/config` با ETag، cache در `app_meta`؛ refresh حداکثر هر ۶ ساعت.
11. `core/content`: `ContentRepository` (bundled از `assets/content/*.json` + manifest/pack دانلودی، بررسی sha256، `content_cache`)، `CopyResolver.t(key, vars)` مطابق سند ۴۰ §۳ (variant با `hash(key+local_day)`، متغیرها، fallback).
12. interfaceها + impl موقت: `AnalyticsService` (`NoopAnalytics` + `QueueAnalytics` که فقط در `analytics_queue` می‌نویسد)، `NotificationService` (`NoopNotificationService`)، `PaymentGateway` (`FakeGateway`)، `CatRenderer` (`PlaceholderCatRenderer`).
13. `core/router`: همه routeهای سند ۲۰ §۴ با صفحات placeholder؛ redirectها: `onboarding_completed=false` ← `/onboarding/1`؛ `app_version < update.min_supported_version` ← `/update`.
14. `features/system`: Splash، `ForceUpdateScreen` (hard/soft با لینک مارکت per flavor)، `OfflineBanner`، `DbErrorScreen`.
15. CI: `flutter analyze`، `flutter test`، `drift` schema check، `flutter build apk --flavor bazaar --split-per-abi` و myket.

**نساز:** صفحات feature واقعی، پرداخت واقعی، نوتیف واقعی.

## ساختار فایل‌ها
سند ۲۰ §۲ (عیناً). علاوه: `app/tool/sync_assets.dart`، `app/drift_schemas/`، `app/android/brand.properties`.

## قراردادها
- API: سند ۱۰ §۶ (فقط `/auth/device`, `/auth/refresh`, `/config`, `/content/*` در این مرحله).
- جداول: سند ۳۰ §۳ (همه نام‌ها و فیلدها عیناً؛ تغییر ← اول docs).
- کلیدهای config: `config-data/config/default.json` (اگر هنوز وجود ندارد، طبق اسناد ۳۰ §۴–§۵، ۵۰ §۷، ۶۰ §۳ بساز و در `config-data/` بگذار).

## قوانین کدنویسی
00 §۲. هیچ `Text('...')` فارسی hard-code؛ فقط `copy.t(...)`. lint سفارشی (`custom_lint` یا تست) که رشته فارسی در `lib/features` را رد کند.

## معیار پذیرش
- [ ] هر دو flavor build و اجرا می‌شوند؛ نام launcher از `brand.properties`.
- [ ] کل UI راست‌به‌چپ؛ ارقام فارسی؛ تاریخ امروز شمسی درست (تست با تاریخ ثابت: ۲۰۲۶-۱۰-۰۵ ← ۱۳ مهر ۱۴۰۵).
- [ ] `LocalDay` با `day_start_hour=4`: ساعت ۰۳:۳۰ ← دیروز.
- [ ] فایل DB روی دیسک بدون کلید باز نمی‌شود (رمزنگاری واقعی).
- [ ] بدون شبکه، config و content از bundled بارگذاری و `copy.t` کار می‌کند.
- [ ] با سرور mock: ثبت دستگاه، refresh با ۴۰۱ و retry، ETag ← 304.
- [ ] outbox: عملیات ناموفق با backoff دوباره اجرا می‌شود و بعد از موفقیت حذف.
- [ ] `flutter analyze` بدون هشدار؛ APK arm64 bazaar < ۱۲MB در این مرحله.

## تست‌های لازم
- Unit: digits، Jalali (مرز سال، اسفند کبیسه)، `LocalDay`، `CopyResolver` (variant قطعی، متغیر، fallback)، `AppConfig` merge، backoff outbox.
- DB: باز کردن in-memory، schema dump موجود، تست migration (برای v1 فقط تست ساخت).
- Network: `AuthInterceptor` با `http_mock_adapter`.
- Widget: Splash و ForceUpdate (golden RTL).

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها. **گام بعد:** `11-frontend-core-loop.md`.
