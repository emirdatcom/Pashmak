# پرامپت 02 — احراز هویت، کاربر، دستگاه

## هدف
هویت ناشناس per-install را پیاده کن: ثبت دستگاه، صدور access token (JWT EdDSA) و refresh token (opaque با rotation و تشخیص reuse)، middleware احراز هویت، `GET/DELETE /v1/me` و حذف حساب. اتصال شماره موبایل (OTP) در این مرحله **نیست** (پرامپت 05).

## پیش‌نیازها
- بخوان: `prompts/00-index.md`، `docs/10-architecture-backend.md` §۵.۱، §۶ (endpointهای auth و me)، §۷، §۱۲؛ `docs/80-quality-security-privacy.md` §۴.
- فاز قبلی: 01 تمام‌شده.

## دامنه دقیق
**بساز:**
1. مهاجرت `0002_auth.sql`: جداول `users`, `devices`, `refresh_tokens` دقیقاً مطابق سند ۱۰ §۵.۱. ستون‌های `phone_e164` و `phone_verified_at` (nullable) را همین‌جا بساز تا 05 فقط منطق اضافه کند؛ جدول `otp_challenges` در 05 ساخته می‌شود. ایندکس‌ها: `devices(install_id)` unique، `devices(user_id)`، `refresh_tokens(token_hash)` unique، `refresh_tokens(family_id)`.
2. ماژول `auth`:
   - `POST /v1/auth/device`: اگر `install_id` موجود ← همان user/device (به‌روزرسانی `app_version`, `last_seen_at`)؛ وگرنه user و device جدید. `device_hash = hex(sha256(DEVICE_HASH_SALT || device_hash_raw))`؛ `device_hash_raw` هرگز ذخیره/لاگ نشود. Rate limit: ۱۰/ساعت/IP.
   - `POST /v1/auth/refresh`: rotation؛ اگر توکن ارائه‌شده قبلاً rotate شده ← revoke کل `family_id` و `401 TOKEN_REUSED`.
   - Access JWT: header `alg=EdDSA`, `kid`؛ claims `sub`, `did`, `iat`, `exp` (+۱ ساعت). امضا با `platform/signer` (کلید جدا از entitlement مجاز: `kid` پیشوند `at-`).
   - Refresh: ۳۲ بایت تصادفی base64url؛ ذخیره فقط `sha256`؛ اعتبار ۹۰ روز.
   - Middleware `RequireAuth`: اعتبارسنجی JWT، `user_id`/`device_id` در context، کاربر `deleted` ← `401 UNAUTHENTICATED`.
3. ماژول `user`:
   - `GET /v1/me` ← `{user_id, created_at, phone_linked}`.
   - `DELETE /v1/me` ← تراکنش: `status=deleted`, `deleted_at`, revoke همه refresh tokenها؛ hook برای ماژول‌های دیگر (interface `UserDeletionHook` که entitlement/analytics/backup بعداً پیاده می‌کنند: ناشناس‌سازی events، حذف backup). ← `204`.
4. به‌روزرسانی `api/openapi.yaml`.

**نساز:** OTP/شماره، admin endpointهای کاربر (در 04 کنار سایر admin).

## ساختار فایل‌ها
```
backend/internal/modules/auth/{handler.go, service.go, tokens.go, ports.go, service_test.go, handler_test.go}
backend/internal/modules/user/{handler.go, service.go, deletion.go, ...}
backend/db/migrations/0002_auth.sql
backend/db/queries/{users.sql, devices.sql, refresh_tokens.sql}
```

## قراردادها
| endpoint | ورودی | خروجی | خطا |
|---|---|---|---|
| `POST /v1/auth/device` | `{install_id: uuid, device_hash_raw: string(1..128), market: "bazaar"|"myket", app_version, os_version, model}` | `{user_id, access_token, access_expires_at, refresh_token}` | `INVALID_INPUT`, `RATE_LIMITED` |
| `POST /v1/auth/refresh` | `{refresh_token}` | همان | `TOKEN_INVALID`, `TOKEN_REUSED` |
| `GET /v1/me` | — | `{user_id, created_at, phone_linked}` | `UNAUTHENTICATED` |
| `DELETE /v1/me` | — | 204 | `UNAUTHENTICATED` |

## قوانین کدنویسی
00 §۲. مقایسه hash توکن با `subtle.ConstantTimeCompare`. هیچ توکن یا `device_hash_raw` در لاگ.

## معیار پذیرش
- [ ] دو فراخوانی `/auth/device` با همان `install_id` ← همان `user_id`.
- [ ] `install_id` جدید با همان `device_hash_raw` ← `user_id` جدید ولی `device_hash` یکسان در DB.
- [ ] refresh موفق توکن قبلی را باطل می‌کند؛ استفاده مجدد از توکن قبلی ← `TOKEN_REUSED` و توکن جدید هم باطل می‌شود.
- [ ] access منقضی ← `401`؛ JWT با `kid` ناشناخته ← `401`.
- [ ] `DELETE /v1/me` ← درخواست بعدی با همان access ← `401`؛ refresh ← `TOKEN_INVALID`.
- [ ] ۱۱امین `/auth/device` از یک IP در ساعت ← `429`.
- [ ] OpenAPI به‌روز و تست contract سبز.

## تست‌های لازم
- Unit: service با store fake و fake clock (rotation، reuse، انقضا).
- Integration: کل جریان روی Postgres واقعی.
- Contract: پاسخ‌ها با `openapi.yaml` validate شوند.

## تعریف «تمام شد» و گام بعدی
00 §۲ + معیارها. **گام بعد:** `03-backend-entitlements.md` و `04-backend-config-content-analytics.md` (موازی).
