.PHONY: run test lint sqlc migrate-up migrate-down docker-up
run:
	go run ./cmd/api
test:
	go test ./... -race
lint:
	golangci-lint run ./...
sqlc:
	sqlc generate
migrate-up:
	go run ./cmd/migrate up
migrate-down:
	go run ./cmd/migrate down
docker-up:
	docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d --build
