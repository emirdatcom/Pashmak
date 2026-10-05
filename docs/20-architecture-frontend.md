# ۲۰ — معماری فرانت (Flutter، اندروید)

## ۱. پشته فنی
| موضوع | انتخاب | دلیل | ردشده |
|---|---|---|---|
| SDK | Flutter stable (Dart 3)، فقط Android | قید پروژه | — |
| State | `flutter_riverpod` (بدون codegen در MVP) | تست‌پذیر، override آسان در تست، بدون BuildContext | Bloc (boilerplate بیشتر)، Provider (محدود) |
| ناوبری | `go_router` (ShellRoute برای تب‌ها) | deep link از نوتیف و ویجت، redirect برای آنبوردینگ/آپدیت اجباری | Navigator 2 دستی |
| DB محلی | `drift` + `sqlcipher_flutter_libs` | SQL، migration stepwise، stream query، رمزنگاری | Isar/Hive (migration ضعیف‌تر) |
| Secret | `flutter_secure_storage` (Android Keystore) | کلید DB و توکن‌ها | SharedPreferences |
| HTTP | `dio` با interceptor (auth refresh، retry، timeout) | interceptor بالغ | `http` خام |
| تاریخ شمسی | `shamsi_date` | سبک، بدون وابستگی | پیاده‌سازی دستی |
| نوتیفیکیشن | `flutter_local_notifications` + `timezone` | محلی، بدون FCM | FCM |
| کار پس‌زمینه | `workmanager` (دوره‌ای ۱۲–۲۴ ساعت: reschedule نوتیف، flush outbox، refresh config) | بدون Play Services کار می‌کند (Jetpack WorkManager) | سرویس دائمی |
| ویجت | `home_widget` + AppWidgetProvider بومی Kotlin (RemoteViews) | سبک، پشتیبانی RTL | Glance (حجم بیشتر) |
| انیمیشن | `CatRenderer` abstraction؛ MVP: WebP + `AnimationController`؛ فاز۲: `rive` | حجم و هزینه آرت | Lottie |
| پرداخت | `PaymentGateway` + پلاگین per flavor | چند مارکت | — |
| فونت | Vazirmatn subset (Regular، Bold) | سبک، OFL | — |
| لینت | `flutter_lints` + `very_good_analysis` (زیرمجموعه) | — | — |

> وجود و نگهداری پلاگین Flutter برای Poolakey و Myket **[نیاز به راستی‌آزمایی]** (V4). اگر نبود: `MethodChannel` با کد Kotlin در `android/` per flavor.

## ۲. ساختار پوشه (feature-first)
```
app/
  lib/
    main_bazaar.dart          # entry per flavor → bootstrap(Flavor.bazaar)
    main_myket.dart
    bootstrap.dart            # init DB، DI، error handler، timezone
    app.dart                  # MaterialApp.router، تم، locale fa، Directionality
    core/
      config/                 # RemoteConfigRepository، مدل AppConfig، default_config.json
      content/                # ContentRepository، CopyResolver (متن با متغیر)
      db/                     # AppDatabase (drift)، migrations/، daos/
      network/                # ApiClient (dio)، AuthInterceptor، ApiError
      auth/                   # DeviceIdentity، TokenStore
      outbox/                 # صف عملیات سرور (verify، events، trial)
      time/                   # Clock، LocalDay (day_start_hour)، JalaliFormatter
      analytics/              # AnalyticsService (interface) + BackendAnalytics + NoopAnalytics
      notifications/          # NotificationService (interface) + LocalNotificationService
      payments/               # PaymentGateway (interface)، BazaarGateway، MyketGateway، FakeGateway
      entitlement/            # EntitlementRepository، SignatureVerifier، PremiumGate
      safety/                 # DistressDetector (محلی)
      theme/                  # AppTheme، tokens (رنگ، فاصله، تایپوگرافی)
      widgets/                # ویجت‌های UI مشترک (CatView، Coin، EmptyState، ErrorState)
      router/                 # app_router.dart، routes.dart
      l10n/                   # digits (ارقام فارسی)، plural helpers
    features/
      onboarding/   {data, domain, presentation}
      home/
      cat/                    # CatState، CatRenderer، cat_mood logic
      checkin/
      habits/
      exercises/
      adventure/
      wallet/                 # energy، coins، ledger
      shop/                   # فروشگاه و کمد
      stats/                  # (فاز۲ عمیق؛ MVP: streak + هفته)
      paywall/
      settings/
      safety/                 # صفحه کمک
      system/                 # splash، force update، offline banner
  assets/
    cat/{mood}.webp           # happy, sleepy, sad, proud (+ لایه‌های اکسسوری)
    items/*.webp
    backgrounds/*.webp
    content/*.json            # packهای bundled (copy_fa، exercises، adventures، shop_items)
    config/default_config.json
    fonts/
    keys/entitlement_pub.json # کلیدهای عمومی Ed25519 با kid
  android/
    app/src/bazaar/  app/src/myket/   # manifest و کد بومی per flavor
    app/src/main/kotlin/.../widget/   # AppWidgetProviderها
  test/  integration_test/
```
هر feature: `data/` (repository impl، DAO usage، DTO)، `domain/` (entity، use case، interface repository)، `presentation/` (screen، widget، controller = Notifier).

قاعده وابستگی: `presentation → domain ← data`. featureها فقط از طریق `domain` هم را می‌بینند (مثلاً `habits` برای دادن انرژی `WalletService` از `wallet/domain` را صدا می‌زند).

## ۳. مدیریت state
- هر صفحه یک `Notifier`/`AsyncNotifier` (controller). داده‌ی پایدار از `StreamProvider` روی کوئری‌های drift (UI خودکار به‌روز می‌شود، ویجت هم).
- سرویس‌های cross-cutting (`clockProvider`, `analyticsProvider`, `paymentGatewayProvider`, `notificationServiceProvider`, `remoteConfigProvider`, `premiumProvider`) به‌صورت Provider؛ در تست override می‌شوند.
- Use caseها کلاس‌های ساده (بدون Riverpod) هستند و با Provider ساخته می‌شوند ← تست unit خالص.
- `premiumProvider`: `bool` مشتق از `EntitlementRepository` (توکن امضاشده + grace).

## ۴. ناوبری
| route | صفحه | نکته |
|---|---|---|
| `/splash` | Splash | init؛ تصمیم redirect |
| `/onboarding/:step` | آنبوردینگ ۴ مرحله | تا `onboarding_completed=false` همه routeها redirect |
| `/home` | خانه (ShellRoute با تب‌ها: خانه، عادت‌ها، تمرین‌ها، فروشگاه) | |
| `/checkin` | چک‌این (modal) | deep link از نوتیف و ویجت |
| `/habits`, `/habits/new`, `/habits/:id`, `/habits/:id/edit` | | `new` با PremiumGate برای عادت ۴ام/سفارشی |
| `/exercises`, `/exercises/:id/run` | | |
| `/adventure`, `/adventure/result/:id` | | |
| `/shop`, `/shop/closet` | | |
| `/stats` | | |
| `/paywall?trigger=...` | پی‌وال | `trigger` برای آنالیتیکس |
| `/settings/...` | | |
| `/safety` | صفحه کمک | از هر جا قابل دسترس، بدون gate |
| `/update` | آپدیت اجباری/پیشنهادی | redirect اگر `app_version < min_supported_version` |

Deep link scheme: `{app_scheme}://checkin`, `://habits/:id`, `://adventure` (payload نوتیف و ویجت).

## ۵. لایه داده محلی و همگام‌سازی
- جزئیات جداول: سند ۳۰.
- کلید SQLCipher: ۳۲ بایت تصادفی در Keystore (`flutter_secure_storage`). اگر Keystore خراب شد (برخی دستگاه‌ها) ← صفحه خطای مهربان + گزینه بازگردانی از backup (فاز۲) یا شروع تازه؛ این مسیر تست شود.
- **Outbox**: جدول `outbox` (سند ۳۰). هر عملیات شبکه‌ای (`trial_start`, `purchase_verify`, `events_flush`) اول در outbox نوشته می‌شود؛ `OutboxWorker` هنگام باز شدن اپ، تغییر اتصال، و WorkManager اجرا می‌کند؛ backoff نمایی تا ۶ ساعت.
- Config و content: هنگام اجرا (حداکثر هر ۶ ساعت) با ETag؛ fallback به bundled.

## ۶. تم، RTL، تقویم شمسی
- `locale: fa_IR`، `Directionality.rtl` سراسری؛ آیکون‌های جهت‌دار با `matchTextDirection`.
- ارقام: `toPersianDigits()` فقط در لایه نمایش؛ ورودی عددی کاربر نرمال‌سازی به لاتین.
- تاریخ: `LocalDay` (گرگوری داخلی، `YYYY-MM-DD`) ← نمایش با `JalaliFormatter` (`۱۴ مهر ۱۴۰۵`، نام روز هفته). هفته از **شنبه** شروع می‌شود.
- تم: پالت گرم (کرم، نارنجی گربه، فیروزه‌ای گردنبند)، حالت روشن (MVP) + تیره (تنظیمات)؛ tokens در `core/theme/tokens.dart`؛ کنتراست AA.
- اندازه متن: پشتیبانی `textScaler` تا ۱.۳ بدون شکستن layout.

## ۷. سیستم نوتیفیکیشن
`NotificationService` (interface): `scheduleAll(plan)`, `cancelType(type)`, `requestPermission()`, `onTap(stream<payload>)`.
`NotificationPlanner` (domain، خالص): از تنظیمات کاربر + config + وضعیت امروز، فهرست نوتیف‌های ۷ روز آینده را تولید می‌کند. جزئیات: سند ۵۰.

## ۸. ویجت اندروید (فاز ۲)
- Flutter بعد از هر تغییر مرتبط، snapshot کوچک (`WidgetSnapshot`: cat_mood، habits_today[≤3]: id, title, done، streak، checked_in_today) را با `home_widget` در SharedPreferences می‌نویسد و `updateWidget` می‌زند.
- Kotlin `AppWidgetProvider` با RemoteViews رندر می‌کند (`layoutDirection=rtl`).
- تیک سریع و چک‌این سریع: `HomeWidget` interactivity ← background Dart callback ← use case `CompleteHabit` / `QuickCheckIn` روی همان DB ← snapshot جدید. اگر callback ممکن نبود (محدودیت باتری)، باز کردن اپ با deep link.
- به‌روزرسانی دوره‌ای: `updatePeriodMillis` = 0؛ فقط event-driven + یک بار در شروع روز جدید با WorkManager.

## ۹. انیمیشن گربه
```
abstract CatRenderer { Widget build(CatVisualState state); }
CatVisualState { mood, accessories[], background, activity (idle|eating|away|returning) }
```
- `StaticCatRenderer` (MVP): WebP per mood + لایه اکسسوری روی هم + حرکت کد-محور (نفس‌کشیدن با scale ۱.۰۲، پلک با crossfade، bounce هنگام تیک عادت).
- `RiveCatRenderer` (فاز ۲): فایل `.riv` با state machine ورودی‌های `mood` و `activity`؛ با feature flag `features.rive_cat` و lazy-load.
- انتخاب `cat_mood` (domain): قانون در `CatMoodResolver` (سند ۳۰ §۶).

## ۱۰. پرداخت
```
abstract PaymentGateway {
  Market get market;
  Future<void> connect();
  Future<List<StoreProduct>> products(List<String> skus);
  Future<PurchaseResult> purchase(String sku, {bool subscription});
  Future<List<StorePurchase>> restore();
  Future<void> consume(String purchaseToken);   // برای سکه
}
```
- flavor تعیین می‌کند کدام impl در DI بنشیند. `FakeGateway` برای dev/test.
- جریان کامل: سند ۶۰. کلاینت **هیچ‌وقت** خودش premium را فقط با نتیجه SDK فعال نمی‌کند؛ اگر سرور در دسترس نبود: «entitlement موقت» ۷۲ ساعته (`pending_verification`) + outbox، تا تجربه خراب نشود.

## ۱۱. آنالیتیکس
`AnalyticsService.track(name, props)` ← جدول `analytics_queue` ← batch ۵۰تایی یا هر ۶۰ ثانیه/باز شدن اپ ← `POST /v1/events`. نام‌ها enum (`AnalyticsEvent`) مطابق سند ۷۰؛ props با whitelist. کاربر می‌تواند در تنظیمات خاموش کند (opt-out).

## ۱۲. عملکرد
| هدف | اندازه‌گیری |
|---|---|
| APK per-ABI (arm64) < 15MB | `flutter build apk --split-per-abi --analyze-size` |
| شروع سرد < 2s روی دستگاه مرجع (2GB RAM، Android 8) | `integration_test` + `adb shell am start -W` |
| RAM خانه < 150MB | Android Studio profiler |
| بدون jank در خانه (>90% فریم < 16ms) | `flutter run --profile` |
| مصرف باتری: بدون wakeup بیش از WorkManager روزانه | Battery Historian |

تکنیک‌ها: `--split-per-abi`، `--obfuscate --split-debug-info`، `shrinkResources`، تصاویر WebP با `cacheWidth`، lazy-load content packها، فونت subset، `const` widgetها، بدون پکیج‌های سنگین.

## ۱۳. تست
| سطح | ابزار | پوشش |
|---|---|---|
| Unit | `flutter_test`، `mocktail` | use caseها، resolverها، planner نوتیف، economy ≥ 85% |
| DB | drift in-memory (`NativeDatabase.memory()`) | DAOها، migration (`drift_dev` schema dumps + `SchemaVerifier`) |
| Widget | `flutter_test` + golden (فونت فارسی بارگذاری‌شده) | صفحات کلیدی RTL |
| Integration | `integration_test` با `FakeGateway` و سرور mock | آنبوردینگ ← عادت ← ماجراجویی ← خرید |
