# Build context is the repository root (it needs config-data/): docker build -f backend/deploy/Dockerfile .
FROM golang:1.26 AS build
WORKDIR /src/backend
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ ./
RUN for c in api migrate worker admin-cli content-lint alert-relay; do \
      CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/$c ./cmd/$c || exit 1; done

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/ /app/
COPY config-data/ /config-data/
ENV CONFIG_DATA_DIR=/config-data
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/api"]
