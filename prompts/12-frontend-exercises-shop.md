# پرامپت 12 — تمرین‌ها، فروشگاه، کمد گربه

## هدف
تمرین‌های کوتاه (تنفس رایگان + چهار تمرین پریمیوم) با تایمر و راهنما، و فروشگاه آیتم با سکه همراه با کمد (equip اکسسوری، پس‌زمینه و وسایل اتاق) را بساز. همه چیز از content packها و config می‌آید و آفلاین کار می‌کند.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/40-content-and-copy-system.md` §۲، §۵؛ `docs/30-data-and-sync.md` §۳ (`exercise_sessions`, `inventory`, `wallet_ledger`)، §۴؛ `docs/60-monetization-and-entitlements.md` §۳، §۵، §۷ (آیتم‌های پریمیوم پس از انقضا)؛ `docs/70-analytics-and-experiments.md` §۳؛ `docs/20-architecture-frontend.md` §۹.
- فاز قبلی: 10، 11.

## دامنه دقیق
**بساز:**
1. `features/exercises`:
   - فهرست تمرین‌ها از pack `exercises`؛ قفل بر اساس `limits.free_exercises` (منبع نهایی) ← `PremiumGate(trigger: premium_exercise)`.
   - اجرای `timer_steps`: گام‌ها با شمارش معکوس، انیمیشن دایره‌ای `inhale/hold/exhale` (کد-محور، بدون asset سنگین)، مکث/ادامه، خروج امن؛ صفحه روشن می‌ماند (`wakelock` فقط حین تمرین) **[حجم پکیج را بررسی کن؛ اگر سنگین بود از `FLAG_KEEP_SCREEN_ON` با platform channel استفاده کن]**.
   - اجرای `journal_prompt` (شکرگزاری، یادداشت راهنما): سؤال‌ها، ورودی متن ← `exercise_sessions.journal_text` (محلی، رمزشده، هرگز آنالیتیکس).
   - `afternoon_tea`: ۲ دقیقه مکث با گربه در حالت `tea` اگر asset موجود است، وگرنه `happy`.
   - `CompleteExercise` ← انرژی `economy.energy_per_exercise` تا `economy.exercise_rewards_per_day` بار در روز (`reason=exercise_done`, `ref=session.id`)؛ به streak فعالیت می‌دهد.
   - disclaimer غیرپزشکی در صفحه شروع هر تمرین.
   - **هیچ پی‌والی حین یا بلافاصله پس از تمرین** (سند ۶۰ §۵).
2. `features/shop`:
   - آیتم‌ها از pack `shop_items` (`item_key`, `name_key`, `slot`, `price_coins`, `premium_only`, `asset`, `seasonal_key?`).
   - تب‌ها: گربه (collar، hat)، اتاق (`room_*`: سماور، استکان، پتوی گلدار، فرش، کاسه مسی، پشتی)، پس‌زمینه.
   - `BuyItem` ← `spend(coins, shop_purchase, ref=item_key)` + `inventory` در یک تراکنش؛ سکه ناکافی ← پیام مهربان + پیشنهاد ماجراجویی (و لینک خرید سکه که 14 فعال می‌کند).
   - `premium_only` برای کاربر رایگان ← `PremiumGate(trigger: premium_item)` (trigger تعریف‌شده در سند ۶۰ §۳ `paywall.triggers`).
3. `features/shop/closet`: آیتم‌های مالک‌شده، `EquipItem(item_key)` (یکی per slot)، پیش‌نمایش زنده روی `CatView` و پس‌زمینه خانه. آیتم premium equipped بعد از انقضا باقی می‌ماند؛ equip جدید premium قفل.
4. آنالیتیکس: `exercise_started`, `exercise_completed`, `shop_item_purchased`, `item_equipped`.

**نساز:** خرید با پول واقعی (14)، بسته‌های فصلی (16)، صوت.

## ساختار فایل‌ها
`lib/features/exercises/{data,domain,presentation}/`، `lib/features/shop/{data,domain,presentation}/` (شامل `closet/`)، `assets/items/*.webp`، `assets/backgrounds/*.webp`.

## قراردادها
- شناسه تمرین‌ها: `breathing_basic` (رایگان)، `gratitude`, `guided_journal`, `muscle_relax`, `afternoon_tea`.
- slotها: `collar`, `hat`, `background`, `room_*`.
- reasonهای ledger: `exercise_done`, `shop_purchase`.
- رویدادها: سند ۷۰ §۳.

## قوانین کدنویسی
00 §۲. تایمر با `Clock`/`Ticker` تست‌پذیر؛ بدون `Timer` مستقیم در widget.

## معیار پذیرش
- [ ] کاربر رایگان فقط `breathing_basic` را باز می‌کند؛ بقیه ← paywall با trigger درست.
- [ ] تغییر `limits.free_exercises` در config بدون نسخه جدید، قفل‌ها را تغییر می‌دهد.
- [ ] تمرین کامل ← انرژی؛ چهارمین تمرین در روز ← بدون انرژی ولی ثبت می‌شود.
- [ ] خروج وسط تمرین ← `completed_at` خالی، بدون پاداش.
- [ ] خرید آیتم با سکه کافی ← کسر و افزودن به کمد؛ دوبار ← غیرممکن (دکمه «داری»).
- [ ] equip collar ← روی گربه خانه نمایش داده می‌شود.
- [ ] هیچ `journal_text` در `analytics_queue` یا لاگ.

## تست‌های لازم
- Unit: `CompleteExercise` (سقف روزانه)، `BuyItem` (تراکنش، سکه ناکافی)، `EquipItem` (یکتا per slot)، قفل بر اساس config.
- Widget: اجرای تمرین با FakeClock (پیشروی گام‌ها)، فروشگاه/کمد (golden RTL).

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها. **گام بعد:** 15 (پس از 13 و 14).
