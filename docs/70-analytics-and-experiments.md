# ۷۰ — آنالیتیکس و آزمایش‌ها

## ۱. اصول
- خودمیزبان (`POST /v1/events`). بدون SDK شخص ثالث.
- **هرگز**: متن یادداشت/ژورنال، `mood_level`، عنوان عادت سفارشی، شماره تلفن، توکن خرید.
- opt-out در تنظیمات (`analytics_opt_out`) ← **هیچ** رویداد آنالیتیکسی ارسال نمی‌شود و صف محلی پاک می‌شود. (verify خرید، تریال و config آنالیتیکس نیستند و ادامه دارند.)
- نام: `snake_case`، فعل گذشته؛ props: whitelist per event.

## ۲. Props مشترک (خودکار روی همه رویدادها)
`app_version`, `market`, `install_age_days`, `is_premium`, `trial_state` (`none`/`active`/`ended`/`converted`), `session_id`, `exp_{key}` (variant هر آزمایش فعال).

## ۳. کاتالوگ رویداد (canonical)
| `name` | props اختصاصی | زمان |
|---|---|---|
| `app_installed` | — | اولین اجرا |
| `app_opened` | `source` (`launcher`/`notification`/`widget`) | هر باز شدن (session جدید بعد از ۳۰ دقیقه) |
| `onboarding_step_viewed` | `step` (1..4) | |
| `onboarding_completed` | `habits_selected_count`, `notif_permission` (`granted`/`denied`/`skipped`), `cat_name_changed` (bool) | |
| `habit_created` | `template_key` (یا `custom`), `has_reminder` | |
| `first_habit_created` | `template_key` | فقط یک بار |
| `habit_completed` | `template_key` (یا `custom`), `source` (`app`/`widget`/`notification`) | |
| `checkin_completed` | `has_note` (bool)، `source` | **بدون mood_level** |
| `exercise_started` | `exercise_key` | |
| `exercise_completed` | `exercise_key`, `duration_s` | |
| `adventure_started` | `location_key`, `duration_minutes` | |
| `adventure_claimed` | `location_key`, `coins`, `got_item` (bool) | |
| `shop_item_purchased` | `item_key`, `price_coins` | |
| `item_equipped` | `item_key`, `slot` | |
| `streak_updated` | `current`, `freeze_used` (bool) | هنگام تغییر |
| `paywall_viewed` | `trigger`, `variant` | |
| `paywall_plan_selected` | `product_id` | |
| `paywall_closed` | `trigger` | |
| `trial_started` | `provisional` (bool) | |
| `trial_ended` | `converted` (bool) | |
| `purchase_started` | `product_id` | |
| `purchase_completed` | `product_id`, `kind` | بعد از verify موفق |
| `purchase_failed` | `product_id`, `reason` (`user_canceled`/`market_error`/`verify_failed`) | |
| `subscription_canceled` | `product_id` | از سرور (worker) — رویداد سمت سرور |
| `restore_completed` | `restored_count` | |
| `notification_opened` | `type` | |
| `safety_screen_viewed` | `source` (`settings`/`auto_card`) | **بدون** دلیل تشخیص |
| `settings_changed` | `key` (فقط کلیدهای غیرحساس) | |
| `force_update_shown` | `kind` (`soft`/`hard`) | |
| `backup_enabled` | — | فاز ۲ |
| `backup_completed` | `auto` (bool) | فاز ۲؛ بدون اندازه/محتوا |
| `restore_completed_backup` | — | فاز ۲؛ جدا از `restore_completed` (بازگردانی خرید) |
| `phone_linked` | `merged` (bool) | فاز ۲؛ **بدون** شماره |
| `stats_viewed` | `range` (`week`/`month`) | فاز ۲ (آمار پریمیوم) |
| `seasonal_item_purchased` | `seasonal_key` | فاز ۲ |

بازگشت روز ۱/۷/۳۰ **رویداد جدا نیست**؛ از `app_opened` + `install_age_days` در rollup محاسبه می‌شود.

## ۴. قیف‌ها
| قیف | گام‌ها |
|---|---|
| فعال‌سازی | `app_installed` → `onboarding_completed` → `first_habit_created` → `habit_completed` (روز ۰) → `adventure_claimed` (روز ۰–۱) |
| تبدیل | `trial_started` → `paywall_viewed` → `purchase_started` → `purchase_completed` |
| حلقه اصلی روزانه | `app_opened` → (`habit_completed` یا `checkin_completed`) → `adventure_started` → `adventure_claimed` → `shop_item_purchased` |

## ۵. متریک‌ها (rollup روزانه در `daily_metrics`)
| متریک | تعریف |
|---|---|
| D1/D7/D30 retention | نسبت نصب‌های cohort روز X که در روز X+n `app_opened` دارند |
| DAU/WAU/MAU، stickiness | DAU/MAU |
| Activation rate | `% onboarding_completed` با ≥ ۱ `habit_completed` در ۲۴ ساعت |
| Trial start rate | `trial_started / onboarding_completed` |
| Trial→Paid | `purchase_completed` (premium) در ۷ روز بعد از `trial_ended` / `trial_ended` |
| Paywall CVR | `purchase_completed / paywall_viewed` per trigger و variant |
| ARPU / ARPPU | از جدول `purchases` (منبع درآمد، نه events) |
| Churn ماهانه | grantهای منقضی‌شده بدون تمدید / فعال‌های اول ماه |
| Core loop completion | `% DAU` با `adventure_started` |

## ۶. آزمایش‌ها (A/B)
- تعریف در `experiments` (سند ۱۰ §۹)؛ bucketing قطعی سمت سرور؛ variant در `ConfigResponse.experiments` و props `exp_*`.
- **قابل آزمایش**: `pricing.plans` (قیمت/ترتیب/badge)، `paywall.variant`، `paywall.triggers`، `trial.days` (۷ در برابر ۵؛ با احتیاط)، متن‌های onboarding (کلید variant در copy).
- **غیرقابل آزمایش (اخلاقی)**: محتوای صفحه ایمنی، فرکانس نوتیف بالاتر از سقف پیش‌فرض، هر متنی که گناه‌انگیز باشد.
- قواعد: یک آزمایش قیمت در هر زمان؛ حداقل ۲ هفته و حجم نمونه از قبل (power ۸۰٪، MDE تعیین‌شده)؛ کاربر در طول آزمایش variant ثابت دارد؛ کاربرانی که خرید کرده‌اند قیمت خریده‌شده را تا پایان دوره نگه می‌دارند.
- تحلیل: کوئری SQL روی `events` + `purchases` per variant؛ گزارش در `/admin/v1/metrics/daily` (فاز ۲: داشبورد Metabase خودمیزبان).

## ۷. کیفیت داده
- `event_id` برای dedupe؛ `client_ts` در کنار `received_at` (clock skew).
- سرور رویداد با نام ناشناخته یا prop ممنوع را رد/حذف می‌کند و متریک `events_rejected_total{reason}` می‌شمارد.
- تست قرارداد: enum `AnalyticsEvent` در Dart و allowlist در Go از یک فایل منبع (`config-data/analytics/events.json`) تولید/چک می‌شوند.


## یادداشت پرامپت 21
رویدادهای چت پشتیبانی فقط شمارنده‌اند (بدون متن پیام)؛ در `config-data/analytics/events.json` ثبت‌اند.
