# Multi-stage Dockerfile for DevOps Portfolio Sample App
# Stage 1: Build the Go application
FROM golang:1.26-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Create non-root user with a numeric UID that matches the Kubernetes
# securityContext (runAsUser 65532) so hadolint DL3066 stays clean.
RUN adduser -D -g '' -u 65532 appuser

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o /app/main .

# Stage 2: Create minimal runtime image
FROM scratch AS runtime

# Import from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /app/main /app/main

# Use non-root user (numeric UID; see DL3066)
USER 65532

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app/main", "-health-check"]

# Run the application
ENTRYPOINT ["/app/main"]