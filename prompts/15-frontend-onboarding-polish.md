# پرامپت 15 — آنبوردینگ، تنظیمات، حالت‌های خالی/خطا، دسترس‌پذیری، عملکرد

## هدف
تجربه MVP را کامل و قابل‌انتشار کن: آنبوردینگ ۴ مرحله‌ای (معرفی گربه و disclaimer، نام گربه، انتخاب ۱ تا ۳ عادت، مجوز نوتیف و شروع تریال)، تنظیمات کامل (شامل «داده‌های تو» و حذف داده)، آمار پایه MVP، حالت‌های خالی/خطا/آفلاین/آپدیت اجباری، دسترس‌پذیری، و رسیدن به بودجه عملکرد و حجم.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/20-architecture-frontend.md` §۴، §۶، §۱۲؛ `docs/40-content-and-copy-system.md` §۴، §۹؛ `docs/50-notifications.md` §۴ (مجوز)؛ `docs/60-monetization-and-entitlements.md` §۴؛ `docs/70-analytics-and-experiments.md` §۳؛ `docs/80-quality-security-privacy.md` §۲، §۴، §۶.
- فاز قبلی: 10، 11، 12، 13A، 14.

## دامنه دقیق
**بساز:**
1. `features/onboarding` (`/onboarding/:step`):
   1. معرفی `{CAT_NAME}` (گربه با حرکت) + یک خط «پزشکی نیست» + لینک حریم خصوصی.
   2. انتخاب نام گربه (پیش‌فرض `brand.cat_default_name`، ۱–۱۶ نویسه، trim، فیلتر ساده واژه نامناسب با فهرست `name_blocklist` در pack `brand`).
   3. انتخاب ۱ تا ۳ عادت از `habit_templates` (+ زمان یادآوری اختیاری).
   4. pre-prompt نوتیف ← `POST_NOTIFICATIONS`؛ سپس «شروع ۷ روز رایگان» (StartTrial از 14) یا «بعداً».
   - پایان ← `onboarding_completed=true`، replan نوتیف، رفتن به خانه با یک لحظه خوشامد گربه.
   - رویدادها: `app_installed` (اولین اجرا)، `onboarding_step_viewed`, `onboarding_completed{habits_selected_count, notif_permission, cat_name_changed}`.
2. `features/settings`: نوتیف‌ها (از 13A)، روز من (`day_start_hour`)، تم (روشن/تیره/سیستم)، اشتراک من (از 14)، **داده‌های تو** (توضیح ساده، «خروجی داده‌های من» به JSON از طریق share intent، «حذف همه داده‌ها» با تأیید دومرحله‌ای ← پاک کردن DB + secure storage + `DELETE /v1/me` (یا outbox اگر آفلاین))، خاموش کردن آنالیتیکس، پنهان کردن در Recent Apps (`FLAG_SECURE` اختیاری)، تغییر نام گربه، درباره و «پزشکی نیست»، تماس با ما (`brand.support_contact`)، لینک صفحه ایمنی.
3. `features/stats` (MVP): streak فعلی/بلندترین، تقویم هفته جاری شمسی (روزهای فعال)، تعداد تکمیل هر عادت در هفته. نمودار حال و الگوها ← `PremiumGate(trigger: stats_deep)` با placeholder (پیاده‌سازی در 16).
4. حالت‌ها: `EmptyState` (بدون عادت، کمد خالی، بدون ماجراجویی)، `ErrorState` (با دکمه تلاش دوباره)، `OfflineBanner` (فقط وقتی کاری به شبکه نیاز دارد)، ForceUpdate soft (dismissible یک بار در روز) و hard (`update.*`)؛ رویداد `force_update_shown`.
5. **دسترس‌پذیری:** `Semantics` برای همه دکمه‌های آیکونی، CatView و حالت‌های چک‌این؛ هدف لمسی ≥ 48dp؛ کنتراست AA؛ `textScaler` تا ۱.۳ بدون overflow؛ ترتیب فوکوس RTL؛ کاهش حرکت اگر `MediaQuery.disableAnimations`.
6. **عملکرد و حجم:** اندازه‌گیری و رسیدن به اهداف سند ۲۰ §۱۲؛ subset فونت؛ WebP با `cacheWidth`؛ lazy init سرویس‌های غیرضروری بعد از اولین فریم؛ حذف پکیج‌های بلااستفاده؛ گزارش `--analyze-size` در `docs/perf-report.md`.
7. پولیش متن: همه کلیدهای جدید در `config-data/content/copy_fa.json` با لحن سند ۴۰؛ `content-lint` سبز.

**نساز:** backup/OTP/آمار عمیق/ویجت (16 و 13B).

## ساختار فایل‌ها
`lib/features/onboarding/`، `lib/features/settings/` (زیرصفحه‌ها)، `lib/features/stats/`، `lib/core/widgets/{empty_state.dart, error_state.dart, offline_banner.dart}`، `docs/perf-report.md`.

## قراردادها
- routeها: سند ۲۰ §۴. کلیدهای `user_settings` و `app_meta`: سند ۳۰ §۳.
- رویدادها: سند ۷۰ §۳.
- حذف حساب: `DELETE /v1/me` (سند ۱۰ §۶.۱).

## قوانین کدنویسی
00 §۲.

## معیار پذیرش
- [ ] نصب تازه ← آنبوردینگ؛ kill وسط مرحله ۳ ← ادامه از همان مرحله.
- [ ] رد مجوز نوتیف ← اپ کامل کار می‌کند و تنظیمات بنر ملایم نشان می‌دهد.
- [ ] تریال آفلاین در مرحله ۴ کار می‌کند (از 14).
- [ ] «حذف همه داده‌ها» ← اپ مثل نصب تازه به آنبوردینگ برمی‌گردد؛ درخواست حذف به سرور (یا outbox) ارسال شده.
- [ ] خروجی JSON شامل عادت‌ها، لاگ‌ها، چک‌این‌ها و یادداشت‌ها؛ هیچ توکنی در آن نیست.
- [ ] TalkBack: همه کنترل‌های خانه، چک‌این و عادت قابل‌خواندن به فارسی.
- [ ] `textScale=1.3` روی همه صفحات کلیدی بدون overflow (تست widget).
- [ ] APK arm64 هر flavor < 15MB؛ شروع سرد < 2s روی دستگاه مرجع؛ نتایج در `perf-report.md`.

## تست‌های لازم
- Widget: آنبوردینگ کامل؛ تنظیمات حذف داده؛ golden صفحات کلیدی در textScale 1.0 و 1.3 و تم تیره.
- Integration (`integration_test`): نصب ← آنبوردینگ ← تیک عادت ← ماجراجویی (FakeClock) ← claim ← خرید آیتم ← پی‌وال با FakeGateway.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها. **گام بعد:** `20-integration-and-release.md` (MVP)؛ سپس فاز ۲: 05، 13B، 16.
