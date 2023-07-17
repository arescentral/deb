ARG BASE

FROM golang:1.20 AS builder

COPY *.go go.* /src/
COPY vendor/ /src/vendor/
WORKDIR /src
RUN go build *.go

FROM $BASE

COPY --from=builder /src/deb-drone /usr/local/bin/deb-drone

LABEL maintainer="sfiera@twotaled.com"
LABEL org.opencontainers.image.description="Drone plugin to build .deb packages"

ENTRYPOINT /usr/local/bin/deb-drone
