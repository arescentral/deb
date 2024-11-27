ARG BASE

FROM golang:1.22-bookworm AS builder

COPY . /src
WORKDIR /src
RUN go build ./cmd/deb-drone

FROM $BASE

COPY --from=builder /src/deb-drone /usr/local/bin/deb-drone

LABEL maintainer="sfiera@twotaled.com"
LABEL org.opencontainers.image.description="Drone plugin to build .deb packages"

ENTRYPOINT /usr/local/bin/deb-drone
