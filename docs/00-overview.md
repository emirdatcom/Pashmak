# ۰۰ — نمای کلی معماری `{APP_NAME}`

> منبع: `input/01_PRODUCT_SPEC.md` و `input/00_MASTER_PROMPT.md`. این سند نقشه‌ی راه است؛ جزئیات در اسناد ۱۰ تا ۸۰.

## ۱. خلاصه محصول
اپ اندروید فارسی برای **خودمراقبتی و عادت‌سازی** با یک گربه (`{CAT_NAME}`). کاربر عادت/تمرین/چک‌این انجام می‌دهد ← **انرژی** ← گربه به **ماجراجویی** می‌رود ← با **سکه و هدیه** برمی‌گردد ← خرید آیتم. بازار ایران (کافه‌بازار، مایکت)، اشتراک‌محور، بدون تبلیغ، **غیرپزشکی**.

## ۲. اصول طراحی (فنی)
| # | اصل | پیامد فنی |
|---|---|---|
| P1 | Offline-first | منبع حقیقت داده‌ی کاربر = دیتابیس محلی (Drift/SQLite رمزنگاری‌شده). سرور فقط برای entitlement، config، content، analytics و backup. |
| P2 | بدون وابستگی خارجی حیاتی | بدون FCM/Firebase/Google Play Services. نوتیفیکیشن محلی. هاست، پیامک و ذخیره‌سازی ایرانی. |
| P3 | همه‌چیز قابل‌تنظیم از سرور | قیمت، سقف رایگان، مدت ماجراجویی، متن‌ها، پی‌وال، شماره‌های کمک ← `remote-config` و `content`، با مقدار پیش‌فرض bundled در APK. |
| P4 | حریم خصوصی پیش‌فرض | متن یادداشت و حالت احساسی **هرگز** به سرور/آنالیتیکس نمی‌رود (به‌جز backup رمزنگاری‌شده سمت کلاینت). |
| P5 | گوشی ضعیف | APK هدف < 15MB (per-ABI split)، شروع سرد < 2s روی دستگاه 2GB RAM، بدون کار پس‌زمینه‌ی دائمی. |
| P6 | هویت قابل‌تعویض | `{APP_NAME}` و `{CAT_NAME}` فقط در بانک متن و یک فایل `brand config`؛ هیچ رشته‌ی hard-code. |
| P7 | لحن گرم | هیچ متن کاربرمحور در کد؛ همه از content system با قوانین لحن (سند ۴۰). |

## ۳. تصمیم‌های کلیدی
قالب: **تصمیم / دلیل / جایگزین ردشده / ریسک**

| ID | تصمیم | دلیل | ردشده | ریسک |
|---|---|---|---|---|
| D1 | بک‌اند Go، مونولیت ماژولار، `net/http` (Go ≥1.22 routing) + PostgreSQL 16 + `pgx` + `sqlc` + `goose` | تیم کوچک، یک سرور؛ کوئری type-safe بدون ORM | میکروسرویس؛ GORM | sqlc نیاز به codegen در CI |
| D2 | هویت: **کاربر ناشناس per-install** (توکن دستگاه) + اتصال اختیاری شماره موبایل با OTP (فاز ۲) | بدون اصطکاک؛ اپ بدون حساب کار می‌کند | ثبت‌نام اجباری | از دست رفتن داده با حذف اپ ← backup + اتصال شماره |
| D3 | Entitlement **مبتنی بر grant دوره‌دار** (`trial`/`subscription`/`pass`/`promo`) با پاسخ **امضاشده Ed25519** که کلاینت آفلاین اعتبارسنجی می‌کند | مستقل از اینکه مارکت اشتراک خودکار داشته باشد یا نه؛ مقاوم آفلاین | اعتماد کامل به SDK مارکت سمت کلاینت | کلید خصوصی سرور باید محافظت شود |
| D4 | **تریال سمت سرور** (۷ روز، یک‌بار per `device_hash`)؛ اگر آفلاین: تریال موقت محلی تا اولین اتصال | پشتیبانی تریال در مارکت‌ها **[نیاز به راستی‌آزمایی]** | تریال فقط از مارکت | سوءاستفاده با ریست دستگاه (پذیرفته‌شده) |
| D5 | Flutter + **Riverpod** + **go_router** + **Drift (SQLCipher)** | تست‌پذیر، بدون وابستگی به BuildContext؛ مهاجرت اسکیما قوی | Bloc، Isar/Hive | حجم SQLCipher (~3–4MB per ABI) **[نیاز به راستی‌آزمایی]** |
| D6 | **Build flavor per market** (`bazaar`, `myket`) پشت `PaymentGateway` | هر مارکت SDK و قوانین خودش را دارد؛ APK فقط یک SDK | یک APK با همه SDKها | نگهداری دو flavor |
| D7 | نوتیفیکیشن: **فقط محلی** (`flutter_local_notifications`) با زمان‌بندی rolling ۷ روزه؛ پوش سرور خارج از MVP | FCM در ایران غیرقابل‌اتکا | FCM؛ پوش ایرانی در MVP | محدودیت باتری سازندگان چینی (Xiaomi و…) |
| D8 | گربه پشت `CatRenderer`: MVP = **تصاویر WebP ثابت per-mood + حرکت کد-محور**؛ بعداً `RiveCatRenderer` | هزینه‌ی آرت پایین، حجم کم | Rive از روز اول | ارتقای بعدی نیاز به آرت جدید |
| D9 | همگام‌سازی = **Backup/Restore اسنپ‌شات رمزنگاری‌شده سمت کلاینت (E2E)** در فاز ۲؛ نه sync رکوردبه‌رکورد | تک‌دستگاهی غالب است؛ ساده و امن | CRDT/sync دوطرفه | بدون multi-device هم‌زمان |
| D10 | آنالیتیکس **خودمیزبان** (جدول partitioned در Postgres) با batch ingest | قانون «بدون سرویس خارجی»، حریم خصوصی | Firebase/Metrix | مقیاس > ۱۰M رویداد/روز ← ClickHouse در آینده |
| D11 | تقویم: **شمسی**، روز کاربر از `day_start_hour` (پیش‌فرض ۴ صبح) با timezone `Asia/Tehran` | عادت‌های شبانه به روز درست بخورند | نیمه‌شب سخت | — |
| D12 | استقرار: یک VPS ایرانی، Docker Compose (Caddy + api + Postgres)، بکاپ روزانه به object storage ایرانی | سادگی | Kubernetes | SPOF ← RTO هدف ۴ ساعت، اپ آفلاین تحمل می‌کند |

## ۴. نمای سیستم

```mermaid
flowchart LR
  subgraph Device[گوشی اندروید]
    UI[Flutter UI] --> Domain[Domain/UseCases]
    Domain --> LocalDB[(Drift + SQLCipher)]
    Domain --> Pay[PaymentGateway\nBazaar | Myket]
    Domain --> Notif[Local Notifications]
    Widget[Android AppWidget] <--> LocalDB
    Sync[ApiClient + Outbox] --> LocalDB
  end
  Pay <--> Market[(کافه‌بازار / مایکت)]
  Sync <-->|HTTPS /v1| API[Go API مونولیت]
  API --> PG[(PostgreSQL)]
  API -->|verify purchase| MarketAPI[Market Developer API\n[نیاز به راستی‌آزمایی]]
  API -->|OTP فاز۲| SMS[سرویس پیامک ایرانی]
  Admin[Admin minimal] --> API
```

## ۵. نقشه فازها
| فاز | دامنه | پرامپت‌ها |
|---|---|---|
| **MVP** | گربه ۴ حالت (happy, sleepy, sad, proud)، عادت‌ها (سقف ۳ رایگان)، چک‌این، ۱ تمرین رایگان + ۴ پریمیوم، ماجراجویی ساده (۳ مکان)، فروشگاه ساده، نوتیفیکیشن محلی، پی‌وال + تریال + خرید Bazaar/Myket، remote config، content، analytics، ذخیره محلی، صفحه ایمنی | 01–04، 10–12، 13 (بخش نوتیف)، 14، 15، 20 |
| **فاز ۲** | ویجت‌ها، آمار و الگوها (پریمیوم)، بسته‌های فصلی، backup/restore E2E، اتصال شماره (OTP)، انیمیشن Rive | 05، 13 (بخش ویجت)، ارتقای 11/12 |
| **فاز ۳** | ماجراجویی غنی، محتوای تخصصی، اجتماعی سبک، پوش سرور ایرانی | — (پرامپت جدید) |

## ۶. نقشه اسناد
| سند | موضوع |
|---|---|
| `10-architecture-backend.md` | Go: ماژول‌ها، مدل داده، API، امنیت، استقرار |
| `20-architecture-frontend.md` | Flutter: ساختار، state، ناوبری، پرداخت، انیمیشن، ویجت |
| `30-data-and-sync.md` | مدل داده مشترک، offline-first، backup، مهاجرت |
| `40-content-and-copy-system.md` | بانک متن، لحن، متغیرها، به‌روزرسانی از راه دور |
| `50-notifications.md` | انواع، زمان‌بندی، فرکانس، نبود FCM |
| `60-monetization-and-entitlements.md` | پلن، تریال، پی‌وال، entitlement، لبه‌ها |
| `70-analytics-and-experiments.md` | رویدادها، قیف، A/B |
| `80-quality-security-privacy.md` | امنیت، حریم خصوصی، انتشار، ریسک |
| `open-questions.md` | فرض‌ها و سؤال‌های باز |

## ۷. واژه‌نامه مشترک (نام‌های canonical)
| مفهوم | نام در کد/API | توضیح |
|---|---|---|
| کاربر | `user` / `user_id` (UUIDv7) | ناشناس per-install |
| دستگاه | `device` / `install_id` | UUID تولید‌شده در اولین اجرا |
| انرژی | `energy` | از عادت/تمرین/چک‌این؛ خرج ماجراجویی |
| سکه | `coins` | از ماجراجویی؛ خرج فروشگاه |
| دفتر ارز | `wallet_ledger` | همه تغییرات energy/coins |
| حالت گربه | `cat_mood` ∈ `happy, sleepy, sad, proud, curious, tea` | MVP: چهار تای اول |
| حال کاربر (چک‌این) | `mood_level` ∈ 1..5 | ۱=خیلی بد، ۵=خیلی خوب |
| روز کاربر | `local_day` (`YYYY-MM-DD` میلادی، نمایش شمسی) | با `day_start_hour` |
| اشتراک فعال | `entitlement` = `premium` | تنها entitlement فعلی |
| روز بخشش | `streak_freeze` | ماهانه ۱ (configurable) |
