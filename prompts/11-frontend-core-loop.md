# پرامپت 11 — حلقه اصلی: گربه، چک‌این، عادت‌ها، کیف پول، ماجراجویی، streak

## هدف
حلقه اصلی روزانه را کاملاً آفلاین بساز: صفحه خانه با گربه (۴ حالت، `StaticCatRenderer`)، چک‌این احساسی ۵ حالته، عادت‌ها (پایه + سقف رایگان از config)، کیف پول انرژی/سکه با ledger idempotent، ماجراجویی با تأخیر زمانی واقعی و پاداش قطعی، streak با روز بخشش، و تشخیص محلی ناراحتی همراه با صفحه ایمنی. پی‌وال در این مرحله فقط به‌صورت `PremiumGate` (هدایت به route `/paywall`) است.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/30-data-and-sync.md` (کامل، به‌خصوص §۳–§۸)؛ `docs/20-architecture-frontend.md` §۲–§۵، §۹؛ `docs/40-content-and-copy-system.md` (§۳، §۴، §۶، §۷)؛ `docs/60-monetization-and-entitlements.md` §۵ (قوانین ممنوعیت پی‌وال)؛ `docs/70-analytics-and-experiments.md` §۳؛ `docs/80-quality-security-privacy.md` §۵.
- فاز قبلی: 10.

## دامنه دقیق
**بساز:**
1. `features/wallet`: `WalletService` (`grant(currency, delta, reason, refId)` و `spend(...)` در تراکنش؛ unique(`reason`,`ref_id`)؛ سقف `economy.energy_cap`؛ جدول `wallet` به‌عنوان cache جمع ledger)، `WalletBar` (انرژی و سکه).
2. `features/habits`:
   - use caseها: `CreateHabit` (از `habit_templates` یا سفارشی)، `UpdateHabit`, `ArchiveHabit`, `ReorderHabits`, `CompleteHabit(habitId, source)`, `UndoHabit` (قواعد سند ۳۰ §۴)، `TodayHabits` (stream: عادت‌های برنامه‌دار امروز بر اساس `schedule_type`/`weekdays_mask` + وضعیت).
   - سقف: تعداد عادت فعال (`is_locked=false`) ≥ `limits.free_active_habits` و کاربر رایگان ← `PremiumGate(trigger: fourth_habit)`؛ سفارشی ← `PremiumGate(trigger: custom_habit)`.
   - صفحات: فهرست، جزئیات (تقویم هفتگی شمسی ساده)، ساخت/ویرایش (انتخاب از قالب‌ها، تکرار روزانه/روزهای هفته، زمان یادآوری اختیاری).
   - پاداش: `economy.energy_per_habit` با `reason=habit_done`, `ref_id=habit_log.id`.
3. `features/checkin`: modal با ۵ حالت (`mood_level` 1..5، آیکون گربه‌ای + برچسب از copy)، یادداشت اختیاری (حداکثر ۱۰۰۰ نویسه)، `SubmitCheckIn` (اولین چک‌این روز ← `economy.energy_per_checkin`)، پاسخ گربه (copy per mood)، اجرای `DistressDetector`.
4. `features/cat`: `CatMoodResolver` (سند ۳۰ §۶، تابع خالص)، `CatVisualState`، `StaticCatRenderer` (WebP per mood؛ نفس‌کشیدن، پلک، bounce؛ لایه اکسسوری equipped از `inventory`؛ placeholder آرت اگر asset نهایی نیست)، `CatView` با `Semantics`.
5. `features/adventure`:
   - مکان‌ها از content `adventures` + اعداد از `adventure.locations` config؛ مکان‌های خارج از `limits.free_adventure_locations` ← `PremiumGate(trigger: premium_location)`.
   - `StartAdventure(location)`: انرژی کافی؟ ← `spend(energy, reason=adventure_start, ref=adventure.id)`؛ `ends_at = now + duration`؛ پاداش (سکه + item با `item_drop_rate`) **همین لحظه** با seed = hash(`adventure.id`) محاسبه و ذخیره؛ حداکثر یک `active`.
   - وضعیت `returned` وقتی `now ≥ ends_at` (محاسبه هنگام باز شدن/تیک ۱ دقیقه‌ای در صفحه)؛ `ClaimAdventure` ← `grant(coins, adventure_reward)` + inventory + متن داستان (`stories` با weight).
   - ضد دست‌کاری ساعت ملایم (سند ۳۰ §۴) با `last_seen_wall_ms`.
   - صفحات: انتخاب مکان، در حال انجام (شمارش معکوس، گربه away)، نتیجه.
6. `features/streak` (در domain مشترک یا `stats`): `StreakService.evaluate(today)` در شروع روز/باز شدن و بعد از هر فعالیت؛ freeze خودکار و ریست ماهانه (ماه شمسی) طبق سند ۳۰ §۵؛ متن reset بدون سرزنش.
7. `features/home`: سلام بر اساس ساعت (copy variant)، `CatView`، `WalletBar`، کارت streak، فهرست عادت‌های امروز با تیک، دکمه چک‌این (اگر امروز نشده)، کارت ماجراجویی (شروع/در حال انجام/برگشته)، کارت مهربان ایمنی (اگر flag فعال).
8. `core/safety` + `features/safety`: `DistressDetector` (سند ۳۰ §۷، کلیدواژه‌ها از pack `safety`، نرمال‌سازی ی/ک/نیم‌فاصله)، ثبت `safety_flags`، کارت حداکثر هر ۴۸h، صفحه `/safety` (متن همدلانه، خطوط کمک فقط با `verified_at`، `tel:` intent، disclaimer غیرپزشکی). بدون PremiumGate و بدون آنالیتیکس دلیل.
9. `PremiumGate`: widget/helper که با `premiumProvider` (در این مرحله stub: `false` یا override dev) تصمیم می‌گیرد؛ قوانین ممنوعیت سند ۶۰ §۵ (مثلاً بعد از چک‌این با `mood_level ≤ 2` در همان جلسه پی‌وال خودکار نشان نده) را enforce کند.
10. آنالیتیکس: `habit_created`, `first_habit_created`, `habit_completed`, `checkin_completed` (**فقط `has_note` و `source`**)، `adventure_started`, `adventure_claimed`, `streak_updated`, `safety_screen_viewed`, `app_opened`.
11. snapshot ویجت: یک hook `WidgetSnapshotPublisher` (interface با impl no-op) که بعد از تغییرات صدا زده می‌شود (پیاده‌سازی واقعی در 13B).

**نساز:** تمرین‌ها و فروشگاه (12)، نوتیف (13)، پرداخت واقعی (14)، آنبوردینگ (15)، آمار عمیق.

## ساختار فایل‌ها
`lib/features/{home,cat,checkin,habits,wallet,adventure,safety}/{data,domain,presentation}/`، `lib/core/safety/distress_detector.dart`، `lib/features/streak/` (یا `stats/domain/streak_service.dart`)، `assets/cat/{happy,sleepy,sad,proud}.webp`.

## قراردادها
- جداول: سند ۳۰ §۳ (`habits`, `habit_logs`, `checkins`, `wallet`, `wallet_ledger`, `adventures`, `inventory`, `streak_state`, `safety_flags`).
- reasonهای ledger: سند ۳۰ §۳ (عیناً).
- شناسه‌ها: عادت‌ها `water, sleep, short_break, walk, healthy_food, medicine, loved_ones`؛ مکان‌ها `alley, rooftop, courtyard` (+ `bazaar, garden` پریمیوم)؛ mood گربه `happy, sleepy, sad, proud`.
- کلیدهای config: `limits.free_active_habits`, `limits.free_custom_habits`, `limits.free_adventure_locations`, `economy.*`, `adventure.locations`, `streak.freezes_per_month`.
- رویدادها: سند ۷۰ §۳.

## قوانین کدنویسی
00 §۲. همه use caseها تابع `Clock` تزریقی؛ هیچ `DateTime.now()` مستقیم. هر نوشتن چندجدولی در یک تراکنش drift.

## معیار پذیرش
- [ ] تکمیل عادت ← +۱۰ انرژی (پیش‌فرض)؛ تیک دوباره همان روز ← بدون انرژی اضافه؛ undo ← قانون §۴.
- [ ] کاربر رایگان با ۳ عادت فعال، افزودن چهارمی ← رفتن به `/paywall?trigger=fourth_habit`.
- [ ] ماجراجویی ۳۰ دقیقه‌ای: kill اپ و بازگشت بعد از ۳۰ دقیقه ← «برگشته» با همان پاداش از پیش تعیین‌شده؛ عقب بردن ساعت ← پایان زودتر رخ نمی‌دهد.
- [ ] streak: فعالیت دیروز ← ادامه؛ یک روز جاافتاده با freeze ← ادامه و `freezes_left=0`؛ دو روز ← صفر با متن مهربان.
- [ ] `CatMoodResolver` همه شاخه‌ها (جدول تست).
- [ ] ۳ چک‌این `mood_level=1` در ۴ روز ← کارت ایمنی یک بار؛ بعد از ۴۸h دوباره قابل نمایش.
- [ ] هیچ رویداد آنالیتیکس شامل `mood_level` یا متن یادداشت نیست (تست روی `analytics_queue`).
- [ ] همه صفحات بدون شبکه کار می‌کنند.

## تست‌های لازم
- Unit: `WalletService` (idempotency، سقف)، `CompleteHabit/Undo`، `TodayHabits` (weekdays_mask شنبه‌مبنا)، `StartAdventure/Claim` (seed قطعی، clock rollback)، `StreakService` (مرز ماه شمسی)، `CatMoodResolver`، `DistressDetector`، `PremiumGate` (قوانین ممنوعیت).
- DB: تراکنش‌ها روی drift in-memory.
- Widget: خانه در حالت‌های مختلف (golden RTL)، چک‌این.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها. **گام بعد:** 12، 13، 14 (موازی‌پذیر).
