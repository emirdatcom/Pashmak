# پرامپت 21 — هم‌راستاسازی با تصمیم‌های قطعی مالک محصول + پشتیبانی چت real-time درون‌اپ

## هدف
مالک محصول چند تصمیم قطعی گرفته که با بخشی از اسناد و کد فعلی (پرامپت‌های 01 تا 20 پیاده‌سازی شده‌اند) ناسازگار است. کار این پرامپت دو بخش دارد: **A)** اعمال این تصمیم‌ها در کد، config، content و اسناد (نگه‌داشتن شماره‌های اورژانسی عمومی در صفحه ایمنی، حذف S3، جایگزینی کاوه‌نگار با sms.ir، حذف هشدار تلگرام/بله، بستن موضوع پرداخت خارج از مارکت، تأیید جداسازی SDK در flavorها)، و **B)** ساخت قابلیت جدید **پشتیبانی چت real-time داخل اپ** (بک‌اند + پنل اپراتور حداقلی + کلاینت Flutter)، که جای «تماس با ما» را می‌گیرد.

## تصمیم‌های قطعی (منبع حقیقت؛ بر هر چیزی در docs که مغایر باشد مقدم است)
| # | تصمیم | پیامد |
|---|---|---|
| D-1 | **شماره تماس اختصاصی پشتیبانی نداریم؛ ولی شماره‌های اورژانسی عمومی (۱۱۵، ۱۲۳، ۱۴۸۰) در صفحه ایمنی می‌مانند.** | `hotlines` در pack `safety` حفظ می‌شود؛ هر شماره باید قبل از انتشار راستی‌آزمایی و `verified_at` پر شود (V9 باز می‌ماند). هیچ شماره تلفن برای پشتیبانی خود اپ وجود ندارد. |
| D-2 | **پشتیبانی = چت real-time درون‌اپ.** | ماژول جدید `support` (بخش B)؛ `brand.support_contact` با ورودی چت جایگزین می‌شود. |
| D-3 | **فعلاً هیچ فضای S3/object storage نداریم.** | backup کاربر فقط در Postgres (`bytea`)؛ کد S3 و متغیرهای `S3_*`/`BACKUP_STORAGE` حذف؛ بکاپ DB بدون object storage؛ V8 بسته. |
| D-4 | **OTP از sms.ir ارسال می‌شود.** | adapter `smsir` جایگزین `kavenegar`؛ V6 به «فقط راستی‌آزمایی API sms.ir» محدود. |
| D-5 | **هیچ ارسالی به تلگرام یا بله نداریم.** | هشدارهای عملیاتی از طریق پیامک sms.ir به شماره(های) on-call. |
| D-6 | **پرداخت خارج از مارکت نداریم.** | V14 «موضوعیت ندارد» بسته؛ هیچ لینک/متن پرداخت بیرونی در اپ، پی‌وال یا چت. |
| D-7 | **دو خروجی جدا: یکی بازار، یکی مایکت؛ بدون تداخل SDK.** | (فعلاً پیاده شده) باید با چک خودکار CI تضمین شود. |
| D-8 | **دیتابیس PostgreSQL است.** | (فعلاً هست) هیچ ذخیره‌ساز دیگری (Redis، S3، فایل) اضافه نشود؛ چت هم روی Postgres. |
| D-9 | **سرویس پوش ایرانی فعلاً انتخاب نمی‌شود.** | هیچ SDK پوش اضافه نشود؛ اعلان پاسخ پشتیبانی با WebSocket (در اپ) + polling پس‌زمینه + نوتیف محلی. V7 باز می‌ماند (فاز ۳). |

## پیش‌نیازها
- بخوان: `prompts/00-index.md` (قواعد مشترک §۲)، `docs/00-overview.md`، `docs/10-architecture-backend.md` (§۴–§۸، §۱۲–§۱۴)، `docs/20-architecture-frontend.md`، `docs/30-data-and-sync.md` §۷، §۱۰، `docs/40-content-and-copy-system.md` §۲، §۷، `docs/50-notifications.md`، `docs/80-quality-security-privacy.md`، `docs/open-questions.md` (کامل، به‌خصوص بخش‌های «یافته‌های پیاده‌سازی»)، `docs/runbook.md`.
- کد فعلی را مرور کن، به‌خصوص: `backend/internal/modules/{backup,auth/sms,admin}`، `backend/internal/platform/config/config.go`، `backend/internal/app/services.go`، `backend/deploy/*`، `config-data/content/{safety,brand,copy_fa}.json` و schemaها، `app/lib/features/{safety,settings}`، `app/lib/core/{network,background,notifications}`، `app/android/app/build.gradle.kts`، `.github/workflows/*`.
- فاز قبلی: 01–20 (و 05، 13B، 16) پیاده‌شده.

---
## بخش A — هم‌راستاسازی

### A1. صفحه ایمنی: شماره‌های اورژانسی می‌مانند، پشتیبانی اضافه می‌شود (D-1)
- `hotlines` در `config-data/content/safety.json` و `app/assets/content/safety.json` **حفظ** می‌شود (اورژانس ۱۱۵، اورژانس اجتماعی ۱۲۳، صدای مشاور ۱۴۸۰). منطق فعلی «فقط شماره‌های دارای `verified_at` نمایش داده شوند» و دکمه تماس (`tel:` intent، بدون مجوز `CALL_PHONE`) بدون تغییر می‌ماند.
- **[نیاز به راستی‌آزمایی] V9:** هر سه شماره و ساعت کارشان را از منبع رسمی (سایت سازمان بهزیستی، اورژانس کشور) تأیید کن؛ اگر از محیط ساخت ممکن نبود، `verified_at` را `null` بگذار و در open-questions و `release-checklist` به‌عنوان مانع انتشار ثبت کن (مالک محصول تأیید و پر می‌کند).
- `SafetyScreen`: متن همدلانه + شماره‌های اورژانسی تأییدشده + disclaimer غیرپزشکی + دکمه جدید «گفتگو با پشتیبانی» (بخش B) با یک خط شفاف: «پشتیبانی برای سؤال‌ها و مشکلات اپه و جایگزین مشاوره یا کمک فوری نیست؛ در شرایط اضطراری با شماره‌های بالا تماس بگیر.»
- اپ **هیچ شماره تماس اختصاصی پشتیبانی** ندارد؛ هر شماره تلفن در `brand.support_contact` حذف شود (B7).
- کلیدهای copy جدید با لحن سند ۴۰؛ کلیدهای `safety.hotline.*` حفظ.
- `DistressDetector` و کارت مهربان بدون تغییر (کاملاً محلی؛ هیچ سیگنالی از آن به سرور یا چت ارسال نمی‌شود).
- تست‌ها و goldenهای مرتبط به‌روز.

### A2. حذف S3 (D-3)
- حذف `backend/internal/modules/backup/s3.go` و تست آن، متغیرهای `BACKUP_STORAGE`, `S3_*` از `config.go`، `.env*.example` و wiring؛ backup فقط `bytea` در جدول `backups`.
- سقف اندازه backup را به **۵MB** کاهش بده (env `BACKUP_MAX_BYTES`، پیش‌فرض 5242880) و همین را در کلاینت و سند ۱۰ اعمال کن؛ ستون `blob_ref` اگر فقط برای S3 بود، با مهاجرت جدید حذف (expand/contract رعایت شود).
- **بکاپ دیتابیس بدون object storage:** `pg_dump -Fc` شبانه روی volume محلی جدا + رمزنگاری با `age` + کپی offsite با `rsync` روی SSH به یک سرور ایرانی دوم (یا دیسک دوم اگر سرور دوم نیست)؛ نگهداری ۱۴ نسخه محلی و ۳۰ نسخه offsite. اسکریپت در `backend/deploy/backup/` و سرویس cron در compose. runbook و سند ۱۰ §۱۳ به‌روز.

### A3. sms.ir به‌جای کاوه‌نگار (D-4)
- حذف `auth/sms/kavenegar` و متغیرهای `KAVENEGAR_*`.
- adapter جدید `auth/sms/smsir` پیاده‌سازی `SMSSender`، بر پایه سرویس «ارسال وریفای/پترن» sms.ir. **[نیاز به راستی‌آزمایی]**: شکل فعلی API را از مستندات رسمی sms.ir بررسی کن (انتظار: `POST https://api.sms.ir/v1/send/verify` با هدر `x-api-key` و body شامل `mobile`, `templateId`, `parameters: [{name, value}]`). اگر از محیط ساخت دسترسی نبود، همین قرارداد را با تست golden (پاسخ نمونه مستند) پیاده و در open-questions ثبت کن.
- env: `SMS_PROVIDER=smsir|log`، `SMSIR_API_KEY`، `SMSIR_OTP_TEMPLATE_ID`، `SMSIR_OTP_PARAM_NAME` (پیش‌فرض `CODE`)؛ timeout ۸s، retry یک‌باره فقط برای خطای شبکه؛ نگاشت خطاهای sms.ir به `SMS_UNAVAILABLE`؛ کد OTP و شماره کامل هرگز در لاگ.
- متد دوم `SendAlert(ctx, phones []string, text string)` برای A4 (از سرویس ارسال گروهی/خط خدماتی sms.ir؛ **[نیاز به راستی‌آزمایی]**).

### A4. هشدار عملیاتی بدون تلگرام/بله (D-5)
- همه ارجاع‌ها به تلگرام/بله از docs و runbook حذف.
- مسیر هشدار: Prometheus + Alertmanager (اگر در compose نیست، حداقلی اضافه کن؛ فقط شبکه داخلی) ← webhook به `cmd/alert-relay` (باینری کوچک Go در همین ماژول) ← `SendAlert` با sms.ir به `ALERT_PHONES` (env، چند شماره). Throttle: حداکثر یک پیامک per alert در ۳۰ دقیقه و ۲۰ پیامک در روز؛ پیام resolved هم ارسال شود.
- قواعد هشدار سند ۱۰ §۱۴ + «بکاپ شب قبل نبوده» + «صف پیام‌های بی‌پاسخ پشتیبانی > N برای بیش از M دقیقه در ساعات کاری» (از بخش B).

### A5. پرداخت فقط از مارکت و جداسازی SDK (D-6، D-7)
- grep کامل اپ و content برای هر لینک/متن پرداخت بیرونی، درگاه، کارت‌به‌کارت؛ اگر چیزی هست حذف. پنل اپراتور (B) یک متن آماده دارد: «خرید فقط از داخل اپ و از طریق {market} انجام می‌شه.»
- **چک CI جدید**: بعد از build هر flavor، بررسی `classes.dex`/`AndroidManifest` (با `apkanalyzer` یا `unzip` + `dexdump`): APK بازار نباید `ir.myket` یا پکیج billing مایکت را داشته باشد و APK مایکت نباید `ir.cafebazaar`/Poolakey؛ مجوزها و `<queries>` هر flavor فقط مارکت خودش. شکست = CI قرمز.
- `docs/80` §۷ و `docs/store-listing.md` به‌روز.

### A6. پوش (D-9)
- هیچ وابستگی پوش اضافه نشود. در `docs/50-notifications.md` §۸ و open-questions V7 بنویس: «تا انتخاب سرویس پوش، پیام‌های زمان‌حساس (پاسخ پشتیبانی) با polling پس‌زمینه + نوتیف محلی پوشش داده می‌شوند.» معیار انتخاب سرویس پوش آینده را فهرست کن: کار بدون Google Play Services، سرور و داده در ایران، SDK سبک (< 500KB)، امکان ارسال سرور به سرور، شفافیت حریم خصوصی، پایداری روی Xiaomi/Huawei.

---
## بخش B — پشتیبانی چت real-time درون‌اپ

### B1. اصول
- چت **متنی** (MVP این قابلیت): بدون فایل/تصویر (نبود S3)؛ حداکثر ۲۰۰۰ نویسه per پیام.
- هر کاربر **یک گفتگوی باز** دارد؛ اپراتور می‌تواند ببندد؛ پیام جدید کاربر گفتگو را دوباره باز می‌کند.
- کاربر ناشناس کافی است (توکن دستگاه)؛ اتصال شماره لازم نیست.
- **حریم خصوصی:** متن پیام‌ها در DB با AES-GCM (`DATA_ENC_KEY`) رمز؛ هرگز در لاگ/آنالیتیکس؛ نگهداری ۱۲ ماه بعد از بسته شدن (job پاک‌سازی)؛ با `DELETE /v1/me` حذف کامل؛ کاربر می‌تواند گفتگو را از اپ پاک کند. هیچ داده احساسی (حال، یادداشت، `safety_flags`) به‌صورت خودکار به چت پیوست نمی‌شود. فقط متادیتای فنی با رضایت صریح (چک‌باکس «اطلاعات فنی گوشی هم فرستاده بشه»: `app_version`, `market`, `os_version`, `model`, `is_premium`).
- ساعات پاسخ‌گویی از config؛ خارج از آن، پیام ثبت می‌شود و متن «الان آنلاین نیستیم، تا {time} جواب می‌دیم» نشان داده می‌شود.
- اپراتور هرگز مشاوره روان‌شناختی/پزشکی نمی‌دهد؛ متن آماده برای مواقع ناراحتی شدید (هدایت مهربان به آدم مورد اعتماد/متخصص و یادآوری شماره‌های اورژانسی صفحه ایمنی).

### B2. مدل داده (مهاجرت جدید، مثلاً `0006_support.sql`)
| جدول | فیلدها |
|---|---|
| `support_operators` | `id`, `username` (unique), `password_hash` (bcrypt), `display_name` (نام نمایشی به کاربر، مثلاً «سارا از تیم {APP_NAME}»)، `role` (`agent`/`admin`), `active`, `created_at`, `last_login_at` |
| `support_conversations` | `id`, `user_id` FK (unique where status ≠ `closed`)، `status` (`open`/`waiting_user`/`closed`)، `assigned_operator_id` (nullable)، `last_message_at`, `user_unread_count`, `operator_unread`, `device_meta` JSONB (nullable، فقط با رضایت)، `created_at`, `closed_at` |
| `support_messages` | `id` (UUIDv7)، `conversation_id` FK، `sender` (`user`/`operator`/`system`)، `operator_id` (nullable)، `client_msg_id` (uuid، unique per conversation، برای idempotency)، `body_enc` (bytea)، `created_at`, `read_at` |
| `support_canned_replies` | `id`, `key`, `title`, `body`, `active` |
| `operator_sessions` | `id`, `operator_id`, `token_hash`, `expires_at`, `revoked_at` |

ایندکس‌ها برای صف اپراتور (`status, last_message_at`) و تاریخچه (`conversation_id, created_at`).

### B3. انتقال real-time
**تصمیم:** WebSocket (کتابخانه `github.com/coder/websocket`) برای اپ و پنل + **fallback HTTP** (پیمایش با cursor) برای شبکه‌های ناپایدار. Fan-out با **Postgres `LISTEN/NOTIFY`** (کانال `support_events`، payload فقط `conversation_id` و `message_id`) تا در آینده چند instance هم کار کند؛ بدون Redis. **دلیل:** شبکه موبایل ایران ناپایدار است؛ WS تجربه آنی می‌دهد و polling تضمین تحویل. **ردشده:** SSE (پشتیبانی دوطرفه ندارد)، سرویس چت خارجی (قید عدم وابستگی خارجی و حریم خصوصی). **ریسک:** قطع WS توسط پراکسی/اپراتور موبایل ← ping هر ۲۵ ثانیه، reconnect با backoff، و fallback خودکار.

### B4. API کاربر (bearer)
| متد | مسیر | ورودی | خروجی | خطا |
|---|---|---|---|---|
| GET | `/v1/support/conversation` | — | `{conversation_id?, status, unread_count, operator_display_name?, online: bool, next_online_at?}` | — |
| GET | `/v1/support/messages` | `?after=<message_id>&limit=50` یا `?before=` | `{messages: [{id, sender, body, created_at, read_at, operator_display_name?}], has_more}` | — |
| POST | `/v1/support/messages` | `{client_msg_id, body, include_device_meta?: bool}` | پیام ذخیره‌شده (idempotent بر `client_msg_id`) | `INVALID_INPUT`, `RATE_LIMITED` (۲۰ پیام/۱۰ دقیقه)، `SUPPORT_DISABLED` |
| POST | `/v1/support/read` | `{up_to_message_id}` | 204 | — |
| DELETE | `/v1/support/conversation` | — | 204 (حذف پیام‌های کاربر) | — |
| GET | `/v1/support/ws` | WebSocket؛ auth با access token در اولین فریم (`{"type":"auth","token":...}`)، نه در query string | فریم‌ها: `message.new`, `message.read`, `conversation.status`, `typing` (اختیاری)، `ping/pong` | بستن با کد 4401 اگر auth نامعتبر |

کد خطای جدید `SUPPORT_DISABLED` (503) به سند ۱۰ §۶.۳ اضافه شود.

### B5. پنل اپراتور
- `/admin/support/*`: صفحه وب سبک **سرو‌شده از خود باینری** (`embed`؛ HTML + JS خالص یا Alpine.js از فایل محلی، بدون CDN خارجی)، فارسی و RTL.
- ورود: username/password اپراتور ← session cookie (`HttpOnly`, `Secure`, `SameSite=Strict`)، CSRF token، IP allowlist موجود admin؛ rate limit ورود.
- قابلیت‌ها: صف گفتگوها (باز، منتظر، بسته) با مرتب‌سازی بر قدیمی‌ترین بی‌پاسخ، تخصیص به خود، ارسال پیام، پاسخ‌های آماده، بستن/بازکردن، دیدن `device_meta` (اگر رضایت داده شده)، دیدن وضعیت entitlement کاربر (premium/trial، تاریخ پایان) و دکمه promo grant موجود (فقط `role=admin`). **هیچ** دسترسی به داده احساسی (سرور اصلاً ندارد).
- API پنل: `/admin/v1/support/...` (لیست، پیام‌ها، ارسال، assign، close، canned CRUD برای admin) + WS اپراتور `/admin/v1/support/ws`.
- `admin-cli support-operator add|disable|reset-password`.
- هر عمل اپراتور در `admin_audit`.

### B6. کلاینت Flutter (`features/support`)
- صفحه چت (`/support`): حباب‌ها RTL، ارقام فارسی، وضعیت ارسال per پیام (در حال ارسال / ارسال‌شده / خوانده‌شده / خطا + تلاش دوباره)، نام نمایشی اپراتور، بنر ساعات پاسخ‌گویی، چک‌باکس رضایت متادیتای فنی، دکمه «پاک کردن گفتگو».
- ورودی‌ها: تنظیمات («گفتگو با پشتیبانی» به‌جای «تماس با ما»)، صفحه ایمنی (A1)، پیام‌های خطای خرید/restore (`PURCHASE_INVALID`, `PURCHASE_ALREADY_CLAIMED`)، صفحه «اشتراک من».
- **ذخیره محلی:** جدول drift جدید `support_messages_cache` (`id`, `client_msg_id`, `sender`, `body`, `created_at`, `status`, `read_at`) در DB رمزنگاری‌شده؛ مهاجرت drift با `schemaVersion` بعدی و schema dump؛ پیام‌های ارسال‌نشده در outbox (`kind = support_send`) و ارسال خودکار با بازگشت شبکه. این جدول در backup E2E **گنجانده نمی‌شود** (منبع حقیقت سرور است).
- **real-time:** `SupportSocket` فقط وقتی صفحه چت باز است (یا اپ foreground و گفتگوی باز داریم)؛ ping/reconnect با backoff؛ در صورت شکست ۳ بار ← polling هر ۱۰ ثانیه تا WS برگردد.
- **اعلان پاسخ بدون پوش (D-9):** وقتی گفتگوی باز داریم، WorkManager دوره‌ای `support_poll` (هر ۳۰ دقیقه تا ۲۴ ساعت بعد از آخرین پیام کاربر، سپس هر ۶ ساعت تا ۷ روز، سپس متوقف) ← `GET /v1/support/conversation` ← اگر `unread_count` افزایش یافت، نوتیف محلی نوع جدید `support_reply` (کانال جدید `support`؛ متن عمومی بدون محتوای پیام: «جواب پیامت اومده.»؛ tap ← `/support`). این نوع از سقف روزانه و ساعت سکوت تبعیت می‌کند ولی بالاترین اولویت بعد از `trial` را دارد. `docs/50` به‌روز شود.
- Badge پیام خوانده‌نشده روی ورودی تنظیمات.

### B7. Config و content
- config: `support.enabled` (kill switch)، `support.hours` (`[{weekday: 0..6 (شنبه=0), from: "09:00", to: "21:00"}]`)، `support.timezone` (`Asia/Tehran`)، `support.max_message_chars` (2000)، `support.poll_schedule`، `support.unanswered_alert` (`{count, minutes}` برای A4). اضافه به `config.schema.json` و `default.json` و getterهای `AppConfig`.
- content: کلیدهای copy `support.*` با لحن سند ۴۰ (lint سبز)؛ `brand.support_contact` حذف یا به `{type: "in_app_chat"}` تغییر و schema به‌روز.
- پاسخ‌های آماده اولیه (seed): خوشامد، مشکل خرید (فقط از مارکت، D-6)، بازگردانی خرید، نوتیف نمی‌رسد، حذف داده، ناراحتی شدید (با ارجاع به شماره‌های اورژانسی تأییدشده صفحه ایمنی، D-1).

### B8. آنالیتیکس
به `config-data/analytics/events.json` و سند ۷۰ اضافه شود (props بدون متن پیام): `support_opened{source}`, `support_message_sent{has_device_meta}`, `support_reply_received{via: ws|poll}`, `support_conversation_deleted`. سمت سرور (متریک Prometheus، نه رویداد کاربر): `support_first_response_seconds` (histogram)، `support_open_conversations`، `support_ws_connections`.

---
## ساختار فایل‌ها (حداقل)
```
backend/internal/modules/support/{handler.go, ws.go, service.go, notify.go (LISTEN/NOTIFY), crypto.go, ports.go, retention.go, *_test.go}
backend/internal/modules/support/operatorpanel/{handler.go, auth.go, static/ (embed)}
backend/internal/modules/auth/sms/smsir/{adapter.go, adapter_test.go, testdata/}
backend/cmd/alert-relay/main.go
backend/db/migrations/0006_support.sql (+ مهاجرت حذف ستون‌های S3 در صورت نیاز)
backend/db/queries/support_*.sql
backend/deploy/backup/{pg_backup.sh, README.md}  backend/deploy/alertmanager/alertmanager.yml  backend/deploy/prometheus/{prometheus.yml, rules.yml}
app/lib/features/support/{data/{support_api.dart, support_socket.dart, support_repository.dart}, domain/, presentation/support_screen.dart}
app/lib/core/db/ (جدول support_messages_cache + migration)
app/lib/core/background/ (task support_poll)
.github/workflows/app.yml (چک جداسازی SDK)
```

## قراردادها
- API جدید: B4 و B5 → `backend/api/openapi.yaml` و سند ۱۰ §۶.
- جداول: B2 → سند ۱۰ §۵ (بخش جدید «support»)؛ جدول کلاینت → سند ۳۰ §۳.
- نوتیف `support_reply` → سند ۵۰ §۲.
- رویدادها → سند ۷۰ §۳ و `events.json` (تست هم‌خوانی Dart/Go موجود باید سبز بماند).
- env جدید: `SMSIR_API_KEY`, `SMSIR_OTP_TEMPLATE_ID`, `SMSIR_OTP_PARAM_NAME`, `ALERT_PHONES`, `BACKUP_MAX_BYTES` → `.env.example` و runbook.

## قوانین کدنویسی
`prompts/00-index.md` §۲. علاوه:
- هیچ متن پیام چت، کد OTP یا شماره کامل در لاگ، متریک یا آنالیتیکس.
- همه خواندن/نوشتن پیام از مسیر رمزنگاری `support/crypto.go`.
- پنل اپراتور بدون هیچ منبع خارجی (فونت/اسکریپت/CDN)؛ CSP سخت‌گیرانه (`default-src 'self'`).
- هر حذف (کد S3، کاوه‌نگار، شماره تماس پشتیبانی) همراه با حذف تست‌ها، env و ارجاع‌های اسناد؛ هیچ کد مرده باقی نماند (`grep` در معیار پذیرش).

## معیار پذیرش
**بخش A**
- [ ] `grep -rniE "kavenegar|S3_|BACKUP_STORAGE|telegram|تلگرام|بله \(" backend app config-data docs` فقط در بخش «بسته‌شده» open-questions یا تاریخچه نتیجه دارد.
- [ ] صفحه ایمنی شماره‌های اورژانسی دارای `verified_at` را با دکمه تماس نشان می‌دهد، به‌علاوه دکمه پشتیبانی و جمله «جایگزین کمک فوری نیست»؛ شماره بدون `verified_at` نمایش داده نمی‌شود.
- [ ] backup بزرگ‌تر از ۵MB ← `413 BACKUP_TOO_LARGE`؛ کلاینت قبل از ارسال اندازه را چک و پیام مهربان نشان می‌دهد.
- [ ] `pg_backup.sh` روی compose dev اجرا، فایل رمزشده می‌سازد و restore آن روی DB خالی موفق است (مستند در runbook).
- [ ] OTP با `SMS_PROVIDER=smsir` در برابر سرور mock با قرارداد sms.ir موفق؛ خطای ۵xx ← `SMS_UNAVAILABLE`.
- [ ] Alertmanager ← alert-relay ← (sms.ir mock) پیامک؛ throttle رعایت می‌شود.
- [ ] CI: APK بازار هیچ کلاس مایکت ندارد و برعکس؛ با افزودن عمدی وابستگی، CI قرمز می‌شود (یک بار دستی آزموده و در PR توضیح داده شود).

**بخش B**
- [ ] کاربر پیام می‌فرستد ← در پنل اپراتور زیر ۲ ثانیه (WS) ظاهر می‌شود؛ پاسخ اپراتور در اپ باز زیر ۲ ثانیه.
- [ ] قطع شبکه حین ارسال ← پیام در outbox؛ با بازگشت شبکه دقیقاً یک بار ذخیره می‌شود (`client_msg_id`).
- [ ] WS مسدود (شبیه‌سازی) ← fallback polling و تحویل پیام.
- [ ] اپ بسته، اپراتور پاسخ می‌دهد ← حداکثر تا اجرای بعدی `support_poll` نوتیف محلی بدون متن پیام؛ tap ← صفحه چت.
- [ ] خارج از ساعات کاری ← بنر ساعت پاسخ‌گویی؛ پیام ثبت می‌شود.
- [ ] `body_enc` در DB خوانا نیست؛ `DELETE /v1/me` و «پاک کردن گفتگو» پیام‌ها را حذف می‌کنند؛ job نگهداری ۱۲ ماهه کار می‌کند.
- [ ] `device_meta` فقط با تیک رضایت ذخیره می‌شود.
- [ ] اپراتور `agent` به promo grant دسترسی ندارد؛ همه اعمال در `admin_audit`.
- [ ] `support.enabled=false` ← ورودی‌ها پنهان، API ← `SUPPORT_DISABLED`.
- [ ] هیچ متن پیام در لاگ‌های سرور و کلاینت (تست خودکار روی لاگ‌های capture‌شده).

## تست‌های لازم
- Go unit: سرویس support (idempotency، باز/بسته شدن، unread، ساعات کاری با FakeClock)، crypto round-trip، adapter sms.ir (golden)، throttle alert-relay، retention.
- Go integration (testcontainers Postgres): LISTEN/NOTIFY fan-out، WS کاربر↔اپراتور با دو کلاینت تست، auth اپراتور + CSRF، حذف حساب.
- Contract: OpenAPI برای همه endpointهای جدید.
- Dart unit: `SupportRepository` (outbox، ادغام cache و سرور، ترتیب پیام‌ها)، `SupportSocket` (reconnect/backoff/fallback با fake)، زمان‌بندی `support_poll`، planner نوتیف با `support_reply`.
- Dart DB: migration drift نسخه جدید با `SchemaVerifier`.
- Widget/golden: صفحه چت RTL (پیام طولانی، خطا، خارج از ساعت کاری)، صفحه ایمنی با و بدون شماره‌های تأییدشده.
- E2E (staging): ارسال/پاسخ واقعی بین اپ و پنل.

## تعریف «تمام شد» و گام بعدی
«تمام شد» مشترک (`prompts/00-index.md` §۲) + همه معیارهای بالا + به‌روزرسانی اسناد: `00` (D-1 تا D-9 در جدول تصمیم‌ها)، `10`، `20`، `30`، `40`، `50`، `70`، `80`، `runbook.md`، `store-listing.md`، و `open-questions.md` (V8 و V14 به «بسته‌شده» با دلیل؛ V9 باز تا تأیید شماره‌های اورژانسی؛ V6 محدود به sms.ir؛ V7 باز با معیارهای انتخاب؛ ثبت یافته‌های این پرامپت). یک سطر برای این پرامپت به جدول ترتیب و فهرست تغییرات `prompts/00-index.md` اضافه شود.
**گام بعد:** اجرای دوباره `20-integration-and-release.md` با تمرکز بر خرید واقعی در هر دو مارکت (V2–V4)، ارسال واقعی OTP و هشدار با sms.ir، و آموزش اپراتورها روی پنل.
