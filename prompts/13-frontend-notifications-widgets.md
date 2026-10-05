# پرامپت 13 — نوتیفیکیشن محلی (بخش A، MVP) و ویجت اندروید (بخش B، فاز ۲)

## هدف
**A:** سیستم نوتیف کاملاً محلی بدون FCM: planner خالص ۷ روزه با ساعت سکوت، سقف روزانه، کاهش فرکانس، اولویت‌ها، اکشن سریع «انجام شد»، deep link، و replan دوره‌ای با WorkManager. **B:** سه ویجت صفحه اصلی (کوچک، متوسط، چک‌این سریع) با RemoteViews بومی، RTL، کم‌مصرف و کارکرد آفلاین. بخش B فقط وقتی اجرا شود که فاز ۲ شروع شده است.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/50-notifications.md` (کامل)؛ `docs/20-architecture-frontend.md` §۴، §۷، §۸؛ `docs/40-content-and-copy-system.md` §۳–§۴؛ `docs/60-monetization-and-entitlements.md` §۴ (یادآوری تریال)؛ `docs/30-data-and-sync.md` §۳ (`notification_log`, `user_settings`)؛ `docs/open-questions.md` (A14، V10).
- فاز قبلی: 10، 11 (برای B: 15 هم).

---
## بخش A — نوتیفیکیشن (MVP)
### دامنه
1. `core/notifications/local_notification_service.dart`: پیاده‌سازی `NotificationService` با `flutter_local_notifications` + `timezone`؛ کانال‌های `daily`, `reminders`, `cat`, `account` (نام و توضیح از copy)؛ `zonedSchedule` با `inexactAllowWhileIdle`؛ exact فقط برای `habit_reminder` و فقط اگر کاربر مجوز `SCHEDULE_EXACT_ALARM` داده باشد (سوئیچ در تنظیمات)؛ **بدون** `USE_EXACT_ALARM` و بدون `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
2. `features/notifications/domain/notification_planner.dart`: تابع خالص سند ۵۰ §۳ (ورودی‌ها، قواعد ۱ تا ۶، شناسه قطعی، اولویت‌ها، variant متن).
3. `NotificationScheduler` (orchestrator): جمع‌آوری ورودی‌ها از repositoryها ← planner ← `cancelAll` + schedule. Triggerها: باز شدن اپ، تغییر عادت/تنظیمات، تکمیل عادت/چک‌این/تمرین، شروع/claim ماجراجویی، تغییر وضعیت تریال، تغییر timezone، WorkManager روزانه `notif_replan`، ریبوت (receiver پلاگین).
4. tap ← ثبت `opened_at` در `notification_log` + رویداد `notification_opened{type}` + `go_router` به payload route.
5. اکشن «انجام شد» روی `habit_reminder` ← background isolate ← `CompleteHabit(source: notification)` (DB باید از isolate قابل باز شدن باشد؛ کلید از secure storage) ← replan.
6. صفحه تنظیمات نوتیف (`/settings/notifications`): سوئیچ per نوع (پیش‌فرض‌ها سند ۵۰ §۲؛ `streak_gentle` خاموش)، ساعت صبح/عصر، ساعت سکوت، آلارم دقیق، صفحه «نوتیف‌ها نمیان؟» (راهنمای per سازنده از copy).
7. درخواست مجوز `POST_NOTIFICATIONS` به‌صورت تابع قابل‌فراخوانی از آنبوردینگ (15) با pre-prompt.
8. kill switch از راه دور: `notifications.types_enabled`.

### معیار پذیرش A
- [ ] planner: ساعت سکوت ۲۲:۳۰–۰۸:۰۰، `morning` ساعت ۰۷:۰۰ ← منتقل به ۰۸:۰۰.
- [ ] سقف ۳: با ۵ کاندید در یک روز، فقط ۳ با بالاترین اولویت.
- [ ] ۳ `evening_checkin` باز نشده ← یک روز در میان؛ باز شدن یکی ← عادی.
- [ ] تکمیل عادت ← یادآوری امروز همان عادت لغو.
- [ ] ریبوت دستگاه ← نوتیف‌های آینده هنوز زمان‌بندی‌اند (تست دستی روی دستگاه مرجع).
- [ ] اکشن «انجام شد» بدون باز شدن اپ ← انرژی ثبت و `habit_log.source=notification`.
- [ ] متن هیچ نوتیفی شامل حال ثبت‌شده یا یادداشت نیست؛ همه از `copy_fa` ≤ ۸۰ نویسه.
- [ ] نوتیف `trial` روز ۶ و ۷ فقط وقتی تریال فعال است و خرید نشده.

### تست‌های لازم A
- Unit (اکثریت): planner با جدول سناریو و FakeClock (مرز روز با `day_start_hour`، تغییر ماه، تریال، comeback ۳/۷/۱۴).
- Integration: `NotificationScheduler` با `NotificationService` fake (ثبت فراخوانی‌ها).

---
## بخش B — ویجت‌ها (فاز ۲)
### دامنه
1. `WidgetSnapshotPublisher` واقعی (جایگزین no-op در 11) با `home_widget`: `WidgetSnapshot{cat_mood, habits_today[≤3]{id, title, done}, streak, checked_in_today, locale_digits}` در SharedPreferences (فقط عنوان عادت و وضعیت؛ **هیچ** حال/یادداشت).
2. Kotlin در `android/app/src/main/kotlin/.../widget/`:
   - `CatSmallWidget` (2x2): تصویر گربه با mood + نوار پیشرفت عادت‌ها.
   - `HabitsMediumWidget` (4x2): ۳ عادت با تیک + دکمه چک‌این.
   - `QuickCheckInWidget` (4x1): ۵ حالت.
   - `layoutDirection=rtl`، فونت سیستم (بدون فونت سفارشی برای حجم)، ارقام فارسی از snapshot.
3. تعامل: `HomeWidget` interactivity ← background callback Dart ← `CompleteHabit(source: widget)` / `SubmitCheckIn(mood, source: widget)` ← snapshot جدید + `updateWidget`. اگر callback شکست خورد ← باز کردن اپ با deep link (`://habits/{id}`، `://checkin?mood=n`).
4. به‌روزرسانی: event-driven + WorkManager در شروع روز جدید؛ `updatePeriodMillis=0`.
5. رویداد `app_opened{source: widget}` هنگام باز شدن از ویجت.

### معیار پذیرش B
- [ ] تیک در ویجت متوسط ← داده در اپ و ویجت کوچک فوراً به‌روز.
- [ ] چک‌این سریع ← رکورد `checkins` با `source=widget` و انرژی (اگر اولی).
- [ ] شروع روز جدید ← ویجت تیک‌های دیروز را نشان نمی‌دهد.
- [ ] RTL و ارقام فارسی درست؛ بدون شبکه کار می‌کند.
- [ ] هیچ wakeup دوره‌ای اضافه (Battery Historian).

### تست‌های لازم B
- Unit: ساخت snapshot؛ callback handler با DB in-memory.
- دستی: سه دستگاه مرجع (سند ۸۰ §۶).

---
## ساختار فایل‌ها
```
lib/core/notifications/{notification_service.dart, local_notification_service.dart}
lib/features/notifications/{domain/notification_planner.dart, domain/planned_notification.dart, data/notification_scheduler.dart, presentation/notification_settings_screen.dart}
lib/core/widgets_home/{widget_snapshot.dart, widget_snapshot_publisher.dart, widget_callbacks.dart}   # بخش B
android/app/src/main/kotlin/.../widget/*.kt, res/layout/widget_*.xml, res/xml/widget_*_info.xml     # بخش B
```

## قراردادها
- انواع، کلیدهای config و قواعد: سند ۵۰ (عیناً). کلیدهای copy: `notif.{type}.title/body`.
- `habit_logs.source` و `checkins.source` ∈ `app`/`widget`/`notification` (سند ۳۰ §۳).

## قوانین کدنویسی
00 §۲. Kotlin: ktlint، بدون کتابخانه اضافه.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارهای بخش اجراشده. **گام بعد:** A ← 15؛ B ← 16/20.
