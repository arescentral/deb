ARG BASE

FROM $BASE

COPY deb-drone /usr/local/bin/deb-drone

LABEL maintainer="sfiera@twotaled.com"
LABEL org.opencontainers.image.description="Drone plugin to build .deb packages"

ENTRYPOINT /usr/local/bin/deb-drone
