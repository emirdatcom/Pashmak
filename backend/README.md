# Backend (Go)

- اجرا (توسعه): `docker compose -f deploy/docker-compose.dev.yml up -d` سپس `DATABASE_URL=postgres://app:dev@localhost:5432/app?sslmode=disable make migrate-up run`
- تست: `make test` · لینت: `make lint` · sqlc: `make sqlc`
- استقرار: `cp deploy/.env.example deploy/.env` (مقادیر را پر کن)، `go run ./cmd/admin-cli keygen at-1 deploy/keys`، `make docker-up`
- Endpointها: `/healthz`، `/readyz`؛ متریک روی `METRICS_ADDR` (`/metrics`).
- تست یکپارچه (`db/`) به Docker نیاز دارد و بدون آن skip می‌شود.
- تست یکپارچه با Postgres واقعی: `TEST_DATABASE_URL=postgres://user:pass@localhost:5432/postgres?sslmode=disable go test ./...` (برای هر تست یک دیتابیس موقت ساخته می‌شود).
- Endpointهای فعلی: `POST /v1/auth/device`، `POST /v1/auth/refresh`، `GET|DELETE /v1/me`. کلیدهای امضای access token باید kid با پیشوند `at-` داشته باشند (`admin-cli keygen at-1`).
- Entitlement/billing: `GET /v1/entitlements`، `POST /v1/trial/start`، `POST /v1/purchases/verify|restore`. کلید امضای state: `admin-cli keygen ent-1`. seed محصولات: `DATABASE_URL=... go run ./cmd/admin-cli seed-products ../config-data/products.json`.
- adapter جعلی dev/staging: `BILLING_FAKE_ENABLED=true` (توکن‌های `test_valid_*`, `test_refunded_*`, `test_invalid_*`, `test_timeout_*`)؛ در prod رد می‌شود.
- بازتولید fixture امضا: `go test ./internal/modules/entitlement -update`.
- Config/Content/Analytics/Admin: `GET /v1/config`، `GET /v1/content/manifest`، `GET /v1/content/packs/{key}/{version}`، `POST /v1/events`، `/admin/v1/*` (Basic Auth + `ADMIN_IP_ALLOWLIST`).
- ابزارها: `go run ./cmd/content-lint -dir ../config-data` (CI)؛ `admin-cli publish-config|activate-config|publish-content|experiment put` با `ADMIN_URL/ADMIN_USER/ADMIN_PASSWORD`. اولین استقرار: `admin-cli seed-products`, `publish-content ../config-data/content`, `publish-config -activate ../config-data/config/default.json`.
- `CONFIG_DATA_DIR` (پیش‌فرض `../config-data`، در image: `/config-data`) محل schemaها و کاتالوگ رویدادهاست. image را از ریشه‌ی مخزن بساز: `docker build -f backend/deploy/Dockerfile .`
- worker: `reverify_subscriptions`, `create_partitions`, `rollup_daily`, `prune_events`.
- فاز ۲: `POST /v1/auth/phone/otp|verify` (فقط با `SMS_PROVIDER`)، `PUT|GET|DELETE /v1/backup` (blob رمزشده‌ی کلاینت؛ `BACKUP_STORAGE=db|s3`).
