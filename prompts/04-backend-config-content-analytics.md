# پرامپت 04 — Remote Config، Content، Analytics، Admin

## هدف
سه ماژول «سرور به‌عنوان منبع تنظیمات و گیرنده رویداد» را بساز: remote config نسخه‌دار با experiment و bucketing قطعی، content packهای immutable با manifest و ETag، دریافت batch رویدادهای آنالیتیکس با whitelist، rollup روزانه، و endpointهای admin حداقلی با `admin-cli`.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/10-architecture-backend.md` §۵.۳، §۵.۴، §۶ (config، content، events، admin)، §۹–§۱۱؛ `docs/40-content-and-copy-system.md`؛ `docs/50-notifications.md` §۷؛ `docs/60-monetization-and-entitlements.md` §۳؛ `docs/70-analytics-and-experiments.md`؛ `docs/30-data-and-sync.md` §۴–§۵ (کلیدهای economy/streak).
- فاز قبلی: 01، 02.

## دامنه دقیق
**بساز:**
1. مهاجرت `0004_config_content_analytics.sql`: `config_versions`, `experiments`, `content_packs`, `events` (partitioned by range ماهانه روی `received_at`؛ partition ماه جاری و بعدی)، `daily_metrics`.
2. `config-data/config/schema/config.schema.json` (JSON Schema) شامل همه پیشوندها: `limits.*`, `pricing.*`, `trial.*`, `paywall.*`, `entitlement.*`, `economy.*`, `adventure.*`, `streak.*`, `notifications.*`, `safety.*`, `features.*`, `update.*` با کلیدها و پیش‌فرض‌های اسناد ۳۰ §۴–§۵، ۵۰ §۷، ۶۰ §۳. `config-data/config/default.json` معتبر نسبت به schema (همین فایل در APK bundled می‌شود).
3. ماژول `remoteconfig`:
   - `GET /v1/config?known_version=`: نسخه فعال + ادغام overrideهای experimentهای `running` که کاربر در audience آن‌هاست؛ bucketing `fnv1a32(user_id + ":" + key) % 10000`؛ `ETag`؛ `If-None-Match` ← `304`. بدون auth: bucketing با `X-Install-Id`.
   - `ConfigReader` interface برای سایر ماژول‌ها (03 از آن استفاده می‌کند).
   - هدر `X-App-Version` < `update.min_supported_version` ← پاسخ همچنان 200 (کلاینت خودش force update نشان می‌دهد).
4. ماژول `content`:
   - `GET /v1/content/manifest` (ETag) و `GET /v1/content/packs/{pack_key}/{version}` (gzip، `Cache-Control: public, max-age=31536000, immutable`).
   - فیلتر `min_app_version`.
5. ماژول `analytics`:
   - `config-data/analytics/events.json`: کاتالوگ سند ۷۰ §۳ (نام، props با نوع، `server_side: bool`) + props مشترک §۲.
   - `POST /v1/events`: حداکثر ۲۰۰ رویداد/۲۵۶KB؛ رد نام ناشناخته؛ حذف props غیر whitelist؛ **رد صریح** هر prop با نام `mood_level`, `note`, `text`, `title`, `phone` (لایه دفاعی دوم)؛ dedupe با `event_id`؛ پاسخ `{accepted, rejected}`.
   - `ServerEventSink` impl (برای `subscription_canceled` از 03).
   - `UserDeletionHook`: `user_id = NULL` برای events کاربر.
   - Worker jobs: `create_partitions` (روزانه)، `rollup_daily` (D1/D7/D30، DAU/WAU/MAU، trial start rate، paywall CVR per trigger/variant؛ سند ۷۰ §۵)، `prune_events` (> ۱۸ ماه).
6. ماژول `admin` (`/admin/v1/*`، middleware Basic Auth bcrypt + IP allowlist + `admin_audit`): همه endpointهای سند ۱۰ §۶.۴، از جمله `POST /admin/v1/users/{id}/grants` (فراخوانی `entitlement.GrantPromo` از 03؛ اگر 03 هنوز نیست، endpoint را پشت interface بساز).
7. `cmd/admin-cli`: `publish-config <file>`, `activate-config <version>`, `publish-content <dir>`, `experiment put <file>`, `seed-products` (اگر از 03 نیست)؛ اعتبارسنجی محلی schema قبل از ارسال.
8. CI: validate همه فایل‌های `config-data/` با schemaها؛ content-lint (سند ۴۰ §۴: واژه‌های ممنوع از `config-data/content-lint/banned_words.txt`، طول، متغیرهای مجاز، ی/ک عربی) به‌صورت ابزار Go `cmd/content-lint`.
9. Seed اولیه content: اسکلت packهای `brand`, `copy_fa`, `habit_templates`, `exercises`, `adventures`, `shop_items`, `safety` با کلیدهای لازم MVP و متن نمونه موقت (لحن سند ۴۰؛ شماره خطوط کمک **بدون** `verified_at`).

**نساز:** داشبورد UI، ClickHouse، پوش.

## ساختار فایل‌ها
```
backend/internal/modules/{remoteconfig,content,analytics,admin}/...
backend/cmd/{admin-cli,content-lint}/
backend/cmd/worker/jobs/{partitions.go, rollup.go, prune.go}
backend/db/migrations/0004_config_content_analytics.sql
config-data/config/{default.json, schema/config.schema.json}
config-data/content/{brand,copy_fa,habit_templates,exercises,adventures,shop_items,safety}.json
config-data/content/schema/*.schema.json
config-data/analytics/events.json
config-data/content-lint/banned_words.txt
```

## قراردادها
- endpointها: سند ۱۰ §۶.۱ و §۶.۴. `ConfigResponse`: §۶.۲.
- نام رویدادها و props: فقط `config-data/analytics/events.json` (منطبق با سند ۷۰ §۳).
- شناسه‌های canonical (عادت، تمرین، مکان، mood): `prompts/00-index.md` §۳ بند ۶.

## قوانین کدنویسی
00 §۲. پاسخ‌های config/content gzip. insert رویدادها با `COPY` یا batch insert.

## معیار پذیرش
- [ ] انتشار config نامعتبر نسبت به schema ← رد با پیام دقیق.
- [ ] `GET /v1/config` دوبار با `If-None-Match` ← `304`.
- [ ] experiment با دو variant ۵۰/۵۰ روی ۱۰۰۰۰ user_id تصادفی ← توزیع ۵۰±۲٪؛ variant برای یک کاربر پایدار.
- [ ] audience `market=myket` ← کاربران bazaar override نمی‌گیرند.
- [ ] manifest فقط packهای سازگار با `X-App-Version`.
- [ ] رویداد ناشناخته ← `rejected`؛ prop `mood_level` ← کل رویداد رد؛ `event_id` تکراری ← یک ردیف.
- [ ] rollup روی داده seed‌شده اعداد مورد انتظار D1/D7 را می‌دهد.
- [ ] admin از IP خارج allowlist ← `403`؛ هر عملیات admin در `admin_audit`.
- [ ] `content-lint` روی متنی با «درمان» یا «ي» عربی ← شکست CI.

## تست‌های لازم
- Unit: bucketing، merge overrideها، audience filter، whitelist props، content-lint.
- Integration: انتشار/فعال‌سازی/rollback config؛ ingest و rollup؛ partition creation.
- Contract: OpenAPI.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها. **گام بعد:** 05 (فاز ۲) یا 20 (یکپارچه‌سازی MVP).
