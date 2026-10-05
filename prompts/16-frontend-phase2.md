# پرامپت 16 — فرانت فاز ۲: Backup/Restore، اتصال شماره، آمار و الگوها، بسته‌های فصلی، Rive

## هدف
قابلیت‌های فاز ۲ کلاینت را اضافه کن بدون شکستن MVP: backup اسنپ‌شات رمزنگاری‌شده E2E با recovery code و restore روی دستگاه جدید، اتصال اختیاری شماره موبایل با OTP، آمار و الگوهای پریمیوم (نمودار حال و عادت‌ها)، بسته‌های فصلی (نوروز، یلدا، رمضان)، و `RiveCatRenderer` پشت feature flag. (ویجت‌ها در `13` بخش B.)

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/30-data-and-sync.md` §۹–§۱۱؛ `docs/10-architecture-backend.md` §۶ (phone، backup)؛ `docs/40-content-and-copy-system.md` §۲ (`seasonal_*`)؛ `docs/20-architecture-frontend.md` §۹؛ `docs/60-monetization-and-entitlements.md` §۵؛ `docs/80-quality-security-privacy.md` §۱، §۲.
- فاز قبلی: 10–15 (MVP منتشرشده)، سرور 05.

## دامنه دقیق
**بساز:**
1. **Backup (`features/backup`):**
   - فعال‌سازی: تولید recovery code ۲۴ نویسه (الفبای بدون ابهام، گروه‌های ۴تایی)، نمایش، تأیید با تایپ دوباره ۴ نویسه تصادفی، ذخیره code در secure storage (برای backup خودکار).
   - snapshot: export JSON همه جداول کاربر (سند ۳۰ §۱۰؛ بدون `outbox`, `analytics_queue`, `content_cache`, `entitlement_cache`) + `schema_version`؛ gzip ← AES-256-GCM با key = Argon2id(code, salt) (پارامترها: m=64MB یا کمتر روی گوشی ضعیف با سنجش زمان ≤ ۲s، t=3، p=1) ← `PUT /v1/backup`.
   - خودکار: WorkManager روزانه (شبکه unmetered یا اندازه < 1MB)؛ دستی از تنظیمات؛ نمایش «آخرین backup: {date}».
   - Restore: پس از اتصال شماره (یا روی همان حساب) ← `GET /v1/backup` ← ورود recovery code ← رمزگشایی ← upgrade snapshot (زنجیره تابع per `schema_version`) ← نمایش خلاصه (تاریخ، تعداد عادت/چک‌این) ← تأیید صریح ← **جایگزینی کامل** در یک تراکنش ← replan نوتیف.
   - حذف backup از تنظیمات (`DELETE /v1/backup`).
2. **اتصال شماره (`features/account`):** ورود شماره (ارقام فارسی پذیرفته)، OTP ۵ رقمی با تایمر ارسال مجدد (`retry_after_s`)، `merged=true` ← پیشنهاد restore. متن شفاف: «شماره فقط برای برگردوندن حسابت روی گوشی جدیده.»
3. **آمار و الگوها (`features/stats`، پریمیوم):** نمودار هفتگی/ماهانه شمسی حال (میانگین `mood_level` per روز)، heatmap عادت‌ها، «بهترین روز هفته»، همبستگی ساده عادت↔حال («روزهایی که پیاده‌روی کردی، حالت معمولاً بهتر بوده») با متن بدون ادعای علمی/پزشکی. محاسبه کاملاً محلی. نمودار با `CustomPainter` سبک (بدون کتابخانه سنگین) یا `fl_chart` اگر حجم < 300KB.
4. **بسته‌های فصلی:** خواندن packهای `seasonal_{key}` (بازه شمسی `from`/`to`)، آیتم‌های فصلی در تب جدا در فروشگاه، پس‌زمینه/متن خانه فصلی، نوتیف `seasonal`؛ رمضان جدا و محترمانه (بدون gamification مذهبی؛ فقط متن و تم).
5. **Rive:** `RiveCatRenderer` با state machine ورودی‌های `mood`, `activity`؛ lazy-load فقط اگر `features.rive_cat=true` و دستگاه RAM ≥ 3GB (`device_info_plus` یا platform channel)؛ fallback به `StaticCatRenderer`؛ اندازه‌گیری اثر حجم APK در `perf-report.md`.
6. آنالیتیکس جدید (اول به `config-data/analytics/events.json` و سند ۷۰ اضافه کن): `backup_enabled`, `backup_completed{auto}`, `restore_completed_backup`, `phone_linked{merged}`, `stats_viewed{range}`, `seasonal_item_purchased{seasonal_key}`.

**نساز:** sync چنددستگاهی هم‌زمان، ادغام داده، تحلیل سمت سرور.

## ساختار فایل‌ها
```
lib/features/backup/{domain/{snapshot_exporter.dart, snapshot_importer.dart, snapshot_upgraders.dart, crypto.dart}, data/backup_repository.dart, presentation/}
lib/features/account/{phone_link_screen.dart, otp_screen.dart, ...}
lib/features/stats/{domain/insights.dart, presentation/charts/}
lib/features/shop/seasonal/
lib/features/cat/rive_cat_renderer.dart
assets/cat/cat.riv (lazy/اختیاری)
```

## قراردادها
- API: `POST /v1/auth/phone/otp`, `POST /v1/auth/phone/verify`, `PUT/GET/DELETE /v1/backup` (سند ۱۰ §۶.۱).
- هدرهای backup: `X-Backup-Schema`, `X-Backup-Sha256` (sha256 روی ciphertext)، `X-Kdf-Params`.
- packهای فصلی: سند ۴۰ §۲.

## قوانین کدنویسی
00 §۲. recovery code و کلید هرگز در لاگ. عملیات Argon2 در isolate جدا.

## معیار پذیرش
- [ ] backup روی دستگاه A، نصب روی B، اتصال شماره ← restore با recovery code ← داده‌ها یکسان (تست integration با سرور staging).
- [ ] recovery code اشتباه ← پیام واضح؛ هیچ داده محلی تغییر نمی‌کند.
- [ ] snapshot نسخه قدیمی‌تر schema با upgrader بازگردانی می‌شود (تست با fixture).
- [ ] سرور هرگز plaintext دریافت نمی‌کند (تست: body ارسالی entropy بالا و فاقد رشته‌های شناخته‌شده).
- [ ] آمار پریمیوم برای رایگان قفل؛ همه محاسبات آفلاین.
- [ ] pack یلدا فقط در بازه تاریخش ظاهر می‌شود.
- [ ] `features.rive_cat=false` ← هیچ asset Rive بارگذاری نمی‌شود.

## تست‌های لازم
- Unit: crypto (round-trip، tamper)، exporter/importer، upgraders، insights (داده ساختگی)، بازه فصلی شمسی.
- Integration: backup/restore و OTP با mock server.
- Golden: نمودارها RTL.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها. **گام بعد:** `20-integration-and-release.md` (دور فاز ۲).
