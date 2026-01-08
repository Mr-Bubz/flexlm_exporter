# Build stage
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git make

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary with the same flags as promu
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a \
    -tags 'netgo static_build' \
    -ldflags '-s -w' \
    -o flexlm_exporter \
    .

# Runtime stage
FROM docker.io/rockylinux/rockylinux:8
LABEL maintainer="Mario Trangoni <mjtrangoni@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/mjtrangoni/flexlm_exporter"

# Install dependencies and clean cache
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial && \
    dnf -y update && \
    dnf -y install bash-completion redhat-lsb-core strace && \
    dnf -y clean all && \
    rm -f /etc/pki/tls/private/postfix.key

# Copy binary from builder stage
COPY --from=builder /build/flexlm_exporter /bin/flexlm_exporter

# Add exporter user and group
RUN groupadd -g 30001 exporter && \
  useradd --no-log-init -m -d /home/exporter -u 30001 -g 30001 exporter

EXPOSE      9319
USER        exporter
WORKDIR     /home/exporter

RUN mkdir -p /home/exporter/config &&\
  chown -R 30001:30001 /home/exporter/config

# Default home dir
ENV HOME=/home/exporter

ENTRYPOINT  [ "/bin/flexlm_exporter" ]