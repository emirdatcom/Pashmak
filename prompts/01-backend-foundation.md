# پرامپت 01 — اسکلت بک‌اند Go

## هدف
اسکلت قابل‌اجرای بک‌اند را بساز: ماژول Go، پیکربندی، اتصال PostgreSQL، مهاجرت، لاگ ساخت‌یافته، متریک، middlewareهای پایه، خطای استاندارد API، endpointهای health، Docker Compose برای توسعه و استقرار، و CI. هیچ منطق دامنه‌ای در این مرحله ساخته نمی‌شود؛ هدف یک زیربنای تمیز است که ماژول‌های بعدی (02 تا 05) فقط «اضافه» شوند.

## پیش‌نیازها
- بخوان: `prompts/00-index.md`، `docs/00-overview.md`، `docs/10-architecture-backend.md` (کامل، به‌خصوص §۲، §۳، §۴، §۶.۳، §۱۲–§۱۵)، `docs/80-quality-security-privacy.md` §۳.
- فاز قبلی: ندارد.

## دامنه دقیق
**بساز:**
1. `backend/go.mod`، ساختار پوشه سند ۱۰ §۴ (پوشه‌های ماژول خالی با `doc.go` مجاز است).
2. `internal/platform/config`: بارگذاری env با اعتبارسنجی و پیش‌فرض. متغیرها: `APP_ENV` (`dev`/`staging`/`prod`)، `HTTP_ADDR`، `DATABASE_URL`، `DB_MAX_CONNS`، `LOG_LEVEL`، `METRICS_ADDR` (پورت جدا، داخلی)، `ADMIN_USER`، `ADMIN_PASSWORD_HASH` (bcrypt)، `ADMIN_IP_ALLOWLIST`، `SIGNING_KEYS_DIR`، `DEVICE_HASH_SALT`، `DATA_ENC_KEY` (base64، 32 بایت). secret ناقص در `prod` ← خروج با خطا.
3. `internal/platform/db`: pool با `pgx/v5`، helper تراکنش `WithTx(ctx, fn)`، ping در `/readyz`.
4. `internal/platform/log`: `slog` JSON، سطح از env، افزودن `request_id` و `user_id` از context.
5. `internal/platform/httpx`: router (`http.ServeMux`)، middleware به ترتیب: `RequestID` → `Recover` → `Logging` → `Metrics` → `BodyLimit(256KB)` → `RateLimit` (token bucket درون‌حافظه با کلید IP؛ قابل‌استفاده per route) → (auth در 02). Helperهای `WriteJSON`, `DecodeJSON` (رد فیلد ناشناخته)، `WriteError(code)` با فرم سند ۱۰ §۶ و نگاشت کامل §۶.۳.
6. `internal/platform/metrics`: رجیستری Prometheus، `http_requests_total`, `http_request_duration_seconds`, `db_pool_*`؛ سرو روی `METRICS_ADDR`.
7. `internal/platform/signer`: بارگذاری کلیدهای Ed25519 از `SIGNING_KEYS_DIR` (فرمت: `{kid}.key` خصوصی، `{kid}.pub`)، `Sign(payload) (sig, kid)`، `Verify`؛ کلید فعال = آخرین بر اساس نام یا فایل `active_kid`. ابزار `cmd/admin-cli keygen` برای تولید.
8. `internal/platform/clock`: interface `Clock` + impl واقعی + fake برای تست.
9. `cmd/api`: wiring، graceful shutdown (۱۵s)، `GET /healthz`, `GET /readyz`.
10. `cmd/migrate`: goose up/down/status روی `db/migrations`؛ مهاجرت `0001_init.sql` فقط با extensionها (`pgcrypto`) و جدول `admin_audit` (سند ۱۰ §۱۲).
11. `cmd/worker`: اسکلت scheduler ساده (ticker با jitter) و رجیستری job (خالی فعلاً).
12. `sqlc.yaml`، `db/queries/` (خالی/نمونه admin_audit).
13. `deploy/`: `Dockerfile` چندمرحله‌ای (distroless، کاربر nonroot)، `docker-compose.yml` (postgres:16 با volume، api، worker، caddy)، `docker-compose.dev.yml`، `Caddyfile` (reverse proxy، HSTS، فشرده‌سازی)، `.env.example`.
14. `Makefile`: `run`, `test`, `lint`, `sqlc`, `migrate-up`, `migrate-down`, `docker-up`.
15. CI (`.github/workflows/backend.yml` یا معادل): setup Go، `golangci-lint`، `go test ./... -race`، `govulncheck`، `sqlc diff`، build image.
16. `api/openapi.yaml`: نسخه اولیه با health و components مشترک (`Error`, `EntitlementState`, `ConfigResponse`, `Event` — schemaها از سند ۱۰ §۶.۲).

**نساز:** هیچ endpoint دامنه (auth، entitlements، …)، admin endpointها، adapter مارکت.

## ساختار فایل‌ها
```
backend/
  cmd/{api,migrate,worker,admin-cli}/main.go
  internal/platform/{config,db,log,httpx,metrics,signer,clock}/
  internal/modules/{auth,user,entitlement,billing,remoteconfig,content,analytics,backup,admin}/doc.go
  db/migrations/0001_init.sql
  db/queries/admin_audit.sql
  api/openapi.yaml
  deploy/{Dockerfile,docker-compose.yml,docker-compose.dev.yml,Caddyfile,.env.example}
  sqlc.yaml  Makefile  .golangci.yml  README.md
```

## قراردادها
- فرم خطا و کدها: سند ۱۰ §۶ و §۶.۳ (عیناً).
- هدرهای کلاینت (`X-App-Version`, `X-Market`, `X-Install-Id`) در middleware خوانده و در context گذاشته شوند (برای لاگ و ماژول‌های بعدی).
- `/healthz` ← `200 {"status":"ok"}`؛ `/readyz` ← `200 {"status":"ok","db":"ok"}` یا `503`.

## قوانین کدنویسی
`prompts/00-index.md` §۲. علاوه: هیچ وابستگی web framework؛ وابستگی‌های مجاز: `pgx/v5`, `goose/v3`, `prometheus/client_golang`, `golang.org/x/crypto` (bcrypt, argon2)، `testcontainers-go`، `google/uuid` (v7).

## معیار پذیرش
- [ ] `make docker-up` سرویس را بالا می‌آورد؛ `curl /healthz` ← 200؛ توقف Postgres ← `/readyz` ← 503.
- [ ] `cmd/migrate up` و `down` بدون خطا؛ `admin_audit` ساخته می‌شود.
- [ ] درخواست با body > 256KB ← `413 PAYLOAD_TOO_LARGE` با فرم خطای استاندارد.
- [ ] panic در handler ← `500 INTERNAL` با `request_id` و لاگ stacktrace (نه در پاسخ).
- [ ] لاگ هر درخواست JSON با `request_id`, `route`, `status`, `latency_ms`.
- [ ] `/metrics` فقط روی `METRICS_ADDR` در دسترس است.
- [ ] `APP_ENV=prod` بدون `DEVICE_HASH_SALT` ← سرویس شروع نمی‌شود.
- [ ] `admin-cli keygen` جفت کلید تولید می‌کند؛ `signer` امضا و تأیید می‌کند.
- [ ] CI سبز.

## تست‌های لازم
- Unit: config (پیش‌فرض/الزامی)، `WriteError` نگاشت همه کدها، RateLimit (fake clock)، signer (sign/verify، kid ناشناخته).
- Integration (testcontainers): migrate up/down، `/readyz`.
- Middleware: RequestID تولید/عبور از هدر `X-Request-Id`، Recover.

## تعریف «تمام شد» و گام بعدی
«تمام شد» مشترک (00 §۲) + معیارهای بالا. **گام بعد:** `02-backend-auth-user.md`.
