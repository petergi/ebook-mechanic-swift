# Multi-stage Dockerfile for EbookMechanic
# Stage 1: Build the application
FROM golang:1.25-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make ca-certificates tzdata

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download
RUN go mod verify

# Copy source code
COPY . .

# Build the application
# Disable CGO for static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -X main.Version=docker -X main.BuildTime=$(date -u '+%Y-%m-%d_%H:%M:%S')" \
    -o ebook-mechanic .

# Stage 2: Create minimal runtime image
FROM scratch

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the binary
COPY --from=builder /build/ebook-mechanic /ebook-mechanic

# Create a non-root user (using numeric UID for scratch)
USER 65534:65534

# Set working directory for ebooks
WORKDIR /books

# Default command
ENTRYPOINT ["/ebook-mechanic"]

# Default arguments (can be overridden)
CMD ["-dir", "/books", "-no-tui"]

# Labels
LABEL org.opencontainers.image.title="EbookMechanic"
LABEL org.opencontainers.image.description="Blazing-fast ebook library manager and validator"
LABEL org.opencontainers.image.authors="Peter Giannopoulos"
LABEL org.opencontainers.image.source="https://github.com/petergiannopoulos/ebook-mechanic"
LABEL org.opencontainers.image.licenses="MIT"
