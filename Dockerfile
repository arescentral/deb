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

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential \
        devscripts \
        equivs \
        lintian \
        software-properties-common \
 && rm -rf /var/lib/apt/lists/*

COPY --from=go /src/deb-drone /usr/local/bin/deb-drone

ARG BUILDDATE
ARG VERSION
ARG DISTRIBUTION
ARG TITLE
LABEL maintainer="sfiera@twotaled.com"
LABEL org.opencontainers.image.created=$BUILDDATE
LABEL org.opencontainers.image.title=$TITLE
LABEL org.opencontainers.image.description="Drone plugin to build .deb packages"
LABEL org.opencontainers.image.url="https://github.com/arescentral/deb-drone"
LABEL org.opencontainers.image.version=$VERSION

CMD /usr/local/bin/deb-drone
