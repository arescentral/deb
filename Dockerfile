FROM ubuntu:focal AS bootstrap

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y debootstrap

ARG TARGETARCH=amd64
ARG TARGETDISTRIBUTION
ARG TARGETCOMPONENTS

RUN debootstrap \
    --arch=$TARGETARCH \
    --foreign \
    --variant minbase \
    --components=$TARGETCOMPONENTS \
    $TARGETDISTRIBUTION /var/chroot
RUN chroot /var/chroot /debootstrap/debootstrap --second-stage

RUN chroot /var/chroot apt-get update
RUN chroot /var/chroot apt-get upgrade --no-install-recommends
RUN chroot /var/chroot apt-get install --no-install-recommends -y \
    build-essential devscripts equivs lintian software-properties-common
RUN chroot /var/chroot apt-get autoremove --purge
RUN chroot /var/chroot apt-get clean

RUN rm -rf \
    /var/chroot/usr/share/info/* \
    /var/chroot/usr/share/locale/* \
    /var/chroot/usr/share/man/* \
    /var/chroot/var/cache/apt/* \
    /var/chroot/var/lib/apt/lists/* \
    /var/chroot/var/log/*

########################################################################

FROM golang:1.14 AS go

RUN mkdir /src/
WORKDIR /src
COPY go.* /src/
RUN go mod download
COPY *.go /src/
RUN go build *.go

########################################################################

FROM scratch

COPY --from=bootstrap /var/chroot /
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
