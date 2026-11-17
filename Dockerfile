# Stage 1: Build static Go binary
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY app/main.go .
RUN go mod init blue-green-app && CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server main.go

# Stage 2: Minimal Distroless runtime (non-root, no shell)
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=builder /app/server /server
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]
