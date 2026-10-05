# Runbook عملیات

> نوشته‌شده بر اساس کد و Compose موجود. **هیچ‌کدام از این رویه‌ها روی سرور واقعی اجرا نشده‌اند** (محیط ساخت VPS ایرانی، دامنه و دسترسی SSH نداشت)؛ پیش از انتشار یک‌بار روی staging تمرین شوند.

## ۱. اجزا
`caddy :443` → `api :8080` (و `/metrics` فقط روی `:9090` داخل شبکه‌ی docker) · `worker` · `postgres` (volume `pgdata`) · کلیدها در `./keys` (mount فقط‌خواندنی).
Caddy مسیر `/admin/*` را از بیرون ۴۰۴ می‌کند؛ دسترسی admin فقط با SSH tunnel به شبکه‌ی docker و `ADMIN_IP_ALLOWLIST`.

## ۲. استقرار اول (VPS)
1. VPS با Docker؛ فایروال: فقط `22` (key-only، `PasswordAuthentication no`)، `80`، `443`. `9090` و `5432` هرگز باز نشوند.
2. `git clone`؛ `cd backend/deploy`؛ `cp .env.example .env` و پر کردن مقادیر:
   `POSTGRES_PASSWORD`، `DEVICE_HASH_SALT` (ثابت بماند؛ تغییرش یکتایی تریال را می‌شکند)، `DATA_ENC_KEY` (`openssl rand -base64 32`)، `ADMIN_PASSWORD_HASH` (`admin-cli hash-password`)، `API_DOMAIN`.
3. کلیدها (روی یک ماشین امن، نه لزوماً سرور): `cd backend && go run ./cmd/admin-cli keygen at-1 ./deploy/keys` و `... keygen ent-1 ./deploy/keys`؛ پوشه‌ی `deploy/keys` باید برای کاربر `nonroot` (uid 65532) خواندنی باشد و فقط‌خواندنی mount می‌شود.
   کلید **عمومی** `ent-1` را در `app/assets/keys/entitlement_pub.json` بگذار (قالب `{"keys":[{"kid":"ent-1","public_key":"<base64url>"}]}`) و اپ را با آن build کن. **بدون این کلید اپ هیچ state امضاشده‌ای را معتبر نمی‌داند و همه‌ی کاربران رایگان می‌مانند.** کلید خصوصی را جدا از سرور هم نگه‌دار (رمزنگاری‌شده).
4. `docker compose up -d --build` (migrate قبل از api اجرا می‌شود).
5. seed محصولات: `docker compose run --rm --entrypoint /app/admin-cli api seed-products /config-data/products.json` (SKUها را بعد از ساخت در پنل مارکت‌ها اصلاح کن).
6. انتشار config و content با `admin-cli publish-config -activate <file>` و `admin-cli publish-content <dir>` از ماشین مدیر (نیاز به `ADMIN_URL/ADMIN_USER/ADMIN_PASSWORD` و SSH tunnel به `api:8080`، چون Caddy مسیر admin را بیرون می‌بندد).
7. `scripts/smoke.sh https://<API_DOMAIN>`.

## ۳. Deploy و rollback
- Deploy: `git pull && docker compose build && docker compose up -d`. migrate خودکار قبل از api. مهاجرت‌ها باید با نسخه‌ی قبلی api سازگار (expand/contract) باشند تا rollback ممکن بماند.
- Rollback: `git checkout <tag قبلی> && docker compose up -d --build`. اگر مهاجرت جدید شکست خورد: `docker compose run --rm --entrypoint /app/migrate api down` (فقط یک گام) و بعد کد قبلی.
- بعد از هر deploy: `scripts/smoke.sh` و نگاه به `http_requests_total{status=~"5.."}`.

## ۴. چرخش کلید (Ed25519)
- **JWT (`at-`)**: کلید جدید `at-2` بساز؛ `active_kid_at` را به `at-2` تغییر بده؛ کلید قدیمی ≥ ۱ ساعت (عمر access token) برای verify بماند، بعد حذف.
- **Entitlement (`ent-`)**: چون کلید عمومی داخل APK است، **اول** نسخه‌ای با هر دو کلید (`ent-1` و `ent-2`) منتشر کن و صبر کن اکثر کاربران به‌روز شوند، **بعد** `active_kid_ent` را به `ent-2` ببر. کلید قدیمی تا پایان `offline_validity_days + grace_days` در سرور بماند. اگر کلید لو رفت: کلید جدید + force update (`update.min_supported_version`).

## ۵. بکاپ و بازیابی DB
- روزانه (cron روی هاست): 
  اسکریپت `backend/deploy/backup/` (pg_dump → `age` با `AGE_RECIPIENT` → volume محلی → `rsync` به `OFFSITE_*`)؛ نگهداری ۳۰ روز. بدون object storage (D-3).
- بازیابی (RTO ≤ ۴ ساعت): سرور جدید با همان compose، `docker compose up -d postgres`، 
  `gunzip -c app-DATE.dump.gz | docker compose exec -T postgres pg_restore -U app -d app --clean --if-exists`، سپس `up -d`.
- تست restore ماهانه روی سرور جدا؛ زمان‌ها را در `docs/release-checklist-<version>.md` ثبت کن. **تا امروز تست نشده.**
- blobهای backup کاربران (حداکثر ۵MB، `BACKUP_MAX_BYTES`) همیشه داخل همین dump هستند.

## ۶. واکنش به قطعی مارکت
- نشانه: `market_verify_total{result="error"}` بالا، یا `MARKET_UNAVAILABLE`. **اپ نباید کاربر را قفل کند**: خرید در outbox می‌ماند، premium موقت ۷۲ ساعته فعال است و reverify کار worker است.
- اقدام: ۱) وضعیت مارکت را بررسی کن؛ ۲) دست نزن به entitlementها؛ ۳) بعد از برگشتن مارکت `reverify_subscriptions` خودش ادامه می‌دهد؛ ۴) اگر کلید/توکن API باطل شد: توکن جدید در `.env` و `docker compose up -d api worker`.
- خاموش‌کردن اضطراری یک مارکت: `BILLING_BAZAAR_ENABLED=false` (یا Myket) و restart؛ اپ پاسخ `MARKET_UNAVAILABLE` می‌گیرد و خرید را صف می‌کند.

## ۷. هشدارها (حداقل)
5xx > ۲٪ در ۵ دقیقه · `market_verify` خطا > ۲۰٪ · دیسک > ۸۰٪ · `pg_dump` شب قبل نبوده. ابزار: Alertmanager → `alert-relay` → پیامک sms.ir به `ALERT_PHONES` (D-5؛ توکن `ALERT_RELAY_TOKEN`). پیکربندی با promtool و ارسال واقعی راستی‌آزمایی نشده.

## ۷.۱ چت پشتیبانی
- پنل اپراتور: مسیر پنل با IP allowlist؛ اپراتور با `admin-cli support-operator`. خاموش‌کردن اضطراری: `support.enabled=false` در config ← `SUPPORT_DISABLED`.
- پیام پریشانی ← پاسخ آماده‌ی «distress» و ارجاع به صفحه ایمنی (۱۱۵/۱۲۳/۱۴۸۰).

## ۸. موارد اضطراری رایج
| مشکل | اقدام |
|---|---|
| پیام کاربر: «خریدم ولی فعال نشد» | admin: جستجوی purchase با `order_id`؛ `purchase_state`؛ در صورت `pending` یک‌بار reverify دستی؛ کاربر می‌تواند «بازگردانی خرید» بزند |
| content بد منتشر شد | `admin-cli publish-content` نسخه‌ی قبلی با شماره‌ی بالاتر؛ کلاینت pack با نسخه‌ی بالاتر را می‌پذیرد |
| config بد فعال شد | `admin-cli activate-config <نسخه‌ی قبلی>` |
| سرور کاملاً پایین | اپ آفلاین کار می‌کند؛ فقط خرید جدید/تریال معطل است؛ بعد از برگشتن outbox خودش می‌رسد |
