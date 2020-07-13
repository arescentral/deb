ARG BASE

FROM golang:1.14 AS go

RUN mkdir /src/
WORKDIR /src
COPY go.* /src/
RUN go mod download
COPY *.go /src/
RUN go build *.go

########################################################################

FROM $BASE

COPY --from=go /src/deb-drone /usr/local/bin/deb-drone

LABEL maintainer="sfiera@twotaled.com"
LABEL org.opencontainers.image.description="Drone plugin to build .deb packages"

ENTRYPOINT /usr/local/bin/deb-drone
