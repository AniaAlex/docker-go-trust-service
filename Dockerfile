FROM golang:1.25-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git build-base libxslt-dev

# Create a temporary directory for building
RUN mkdir -p /tmp/go-trust-build
WORKDIR /tmp/go-trust-build

# Initialize a new Go module and install go-trust
RUN go mod init temp-build
RUN go get github.com/SUNET/go-trust@latest

# Download the source code to build the main application
RUN go mod download
RUN go list -f '{{.Dir}}' github.com/SUNET/go-trust > /tmp/go-trust-dir

# Build go-trust from the downloaded module
RUN cd $(cat /tmp/go-trust-dir) && CGO_ENABLED=1 go build -ldflags "-X main.Version=containerized-$(date +%Y%m%d)" -o /app/go-trust ./cmd

# Final stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates libxslt bash openssl wget

# Create non-root user
RUN addgroup -g 1000 appgroup && \
    adduser -D -s /bin/sh -u 1000 -G appgroup appuser

# Create necessary directories
RUN mkdir -p /app /etc/go-trust /tmp/tsl-cache && \
    chown -R appuser:appgroup /app /etc/go-trust /tmp/tsl-cache

WORKDIR /app

# Copy the go-trust binary from builder stage
COPY --from=builder /app/go-trust .

# Copy configuration files from the current directory
COPY start.sh .
COPY config/config.example.yaml /etc/go-trust/config.yaml
COPY config/pipeline.yaml .

# Make executables
RUN chmod +x start.sh go-trust

# Switch to non-root user
USER appuser

# Expose port (go-trust default is 6001)
EXPOSE 6001

ENTRYPOINT ["./start.sh"]
