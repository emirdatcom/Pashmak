# Backend (Go)

- اجرا (توسعه): `docker compose -f deploy/docker-compose.dev.yml up -d` سپس `DATABASE_URL=postgres://app:dev@localhost:5432/app?sslmode=disable make migrate-up run`
- تست: `make test` · لینت: `make lint` · sqlc: `make sqlc`
- استقرار: `cp deploy/.env.example deploy/.env` (مقادیر را پر کن)، `go run ./cmd/admin-cli keygen at-1 deploy/keys`، `make docker-up`
- Endpointها: `/healthz`، `/readyz`؛ متریک روی `METRICS_ADDR` (`/metrics`).
- تست یکپارچه (`db/`) به Docker نیاز دارد و بدون آن skip می‌شود.
- تست یکپارچه با Postgres واقعی: `TEST_DATABASE_URL=postgres://user:pass@localhost:5432/postgres?sslmode=disable go test ./...` (برای هر تست یک دیتابیس موقت ساخته می‌شود).
- Endpointهای فعلی: `POST /v1/auth/device`، `POST /v1/auth/refresh`، `GET|DELETE /v1/me`. کلیدهای امضای access token باید kid با پیشوند `at-` داشته باشند (`admin-cli keygen at-1`).
