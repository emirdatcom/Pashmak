# Backend (Go)

- اجرا (توسعه): `docker compose -f deploy/docker-compose.dev.yml up -d` سپس `DATABASE_URL=postgres://app:dev@localhost:5432/app?sslmode=disable make migrate-up run`
- تست: `make test` · لینت: `make lint` · sqlc: `make sqlc`
- استقرار: `cp deploy/.env.example deploy/.env` (مقادیر را پر کن)، `go run ./cmd/admin-cli keygen k1 deploy/keys`، `make docker-up`
- Endpointها: `/healthz`، `/readyz`؛ متریک روی `METRICS_ADDR` (`/metrics`).
- تست یکپارچه (`db/`) به Docker نیاز دارد و بدون آن skip می‌شود.
