# پرامپت 05 — اتصال شماره (OTP) و Backup رمزنگاری‌شده (فاز ۲)

## هدف
دو قابلیت فاز ۲ سمت سرور: (۱) اتصال اختیاری شماره موبایل با OTP از سرویس پیامک ایرانی تا کاربر روی دستگاه جدید به همان حساب برگردد؛ (۲) نگهداری backup اسنپ‌شات **رمزنگاری‌شده سمت کلاینت** (سرور فقط blob ناخوانا را ذخیره می‌کند). sync رکوردبه‌رکورد عمداً ساخته نمی‌شود.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`؛ `docs/10-architecture-backend.md` §۵.۱ (`otp_challenges`)، §۵.۵، §۶ (phone، backup)، §۷، §۱۲؛ `docs/30-data-and-sync.md` §۹–§۱۰؛ `docs/80-quality-security-privacy.md` §۱، §۴؛ `docs/open-questions.md` (A10، A11، V6، V8).
- فاز قبلی: 01، 02، 04.

## دامنه دقیق
**بساز:**
1. مهاجرت `0005_phone_backup.sql`: `otp_challenges`، `backups`؛ ستون `users.phone_hash` (sha256 با salt برای جستجو) و رمزنگاری `phone_e164` با `DATA_ENC_KEY`.
2. port `SMSSender{SendOTP(ctx, phone, code) error}`؛ adapter یک سرویس ایرانی (Kavenegar یا sms.ir یا Ghasedak — **[نیاز به راستی‌آزمایی]** V6: API پترن/قالب، خط خدماتی) + adapter `log` برای dev.
3. `POST /v1/auth/phone/otp`: نرمال‌سازی شماره ایران به E.164 (`+98 9xx…`، پذیرش ارقام فارسی/عربی)، کد ۵ رقمی، hash با bcrypt یا HMAC، انقضا ۲ دقیقه، حداکثر ۵ تلاش، rate limit ۳/ساعت/شماره و ۱۰/ساعت/IP.
4. `POST /v1/auth/phone/verify`:
   - شماره متعلق به هیچ کاربری نیست ← به کاربر فعلی متصل.
   - شماره متعلق به کاربر دیگر (A) و کاربر فعلی (B) تازه است ← **انتقال دستگاه فعلی به A** (device.user_id = A)، revoke توکن‌های B، صدور توکن برای A؛ grantهای B (مثلاً تریال) به A منتقل نمی‌شوند؛ خریدهای B (اگر داشت) به A منتقل می‌شوند. پاسخ شامل `merged: true`.
5. ماژول `backup`:
   - `PUT /v1/backup`: body باینری ≤ ۱۰MB، هدرهای `X-Backup-Schema`, `X-Backup-Sha256` (بررسی), `X-Kdf-Params` (JSON: `alg=argon2id, m, t, p, salt`)؛ ذخیره در object storage S3-compatible ایرانی (**[نیاز به راستی‌آزمایی]** V8) یا `bytea` اگر `BACKUP_STORAGE=db`؛ فقط آخرین نسخه نگه داشته می‌شود.
   - `GET /v1/backup`: stream blob + همان هدرها + `updated_at`.
   - `DELETE /v1/backup`.
   - Rate limit: ۲۰ PUT/روز/user.
   - `UserDeletionHook`: حذف blob.
6. Admin: `GET /admin/v1/users/{id}` نشان دادن `phone_linked` (نه شماره کامل؛ فقط ۴ رقم آخر).
7. OpenAPI به‌روز.

**نساز:** رمزگشایی سمت سرور (ممنوع)، sync دوطرفه، ادغام داده.

## ساختار فایل‌ها
```
backend/internal/modules/auth/phone.go (+ tests)
backend/internal/modules/auth/sms/{kavenegar|smsir|ghasedak, log}/adapter.go
backend/internal/modules/backup/{handler.go, service.go, storage.go, s3.go, dbstore.go}
backend/db/migrations/0005_phone_backup.sql
```

## قراردادها
- endpointها و خطاها: سند ۱۰ §۶.۱ (ردیف‌های phone و backup).
- خروجی verify: `{user_id, access_token, access_expires_at, refresh_token, merged}`.

## قوانین کدنویسی
00 §۲. شماره کامل هرگز در لاگ (فقط `+98****1234`). کد OTP هرگز در لاگ prod.

## معیار پذیرش
- [ ] OTP درست ← اتصال؛ اشتباه ۵ بار ← challenge باطل.
- [ ] شماره با ارقام فارسی «۰۹۱۲…» ← `+98912…`.
- [ ] سناریوی دستگاه جدید: کاربر B تازه، verify شماره A ← درخواست‌های بعدی به‌عنوان A؛ `GET /v1/backup` blob A را برمی‌گرداند.
- [ ] `PUT` با sha256 نادرست ← `400 INVALID_INPUT`؛ > ۱۰MB ← `413 BACKUP_TOO_LARGE`.
- [ ] `DELETE /v1/me` ← blob حذف.
- [ ] هیچ مسیری در کد سرور blob را رمزگشایی یا parse نمی‌کند.

## تست‌های لازم
- Unit: نرمال‌سازی شماره (جدول ورودی‌ها)، قواعد OTP، merge.
- Integration: جریان کامل OTP با adapter `log`؛ backup با storage `db` و MinIO (testcontainers) به‌عنوان جایگزین S3.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها + V6/V8 در open-questions به‌روز. **گام بعد:** `16-frontend-phase2.md`.
