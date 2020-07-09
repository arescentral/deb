#!/bin/bash

set -o errexit
set -o nounset

if [[ $# != 1 ]]; then
    echo >&2 "usage: ./build.sh CODENAME"
    echo >&2 "                  CODENAME"
    exit 64
fi

CODENAME=$1

TITLE=arescentral/deb

BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
REVISION=2

case $CODENAME in
    bullseye|buster|stretch|jessie)
        DIST=debian VERSION=$CODENAME-20200607 ;;
    focal) DIST=ubuntu VERSION=$CODENAME-20200606 ;;
    bionic) DIST=ubuntu VERSION=$CODENAME-20200526 ;;
    xenial) DIST=ubuntu VERSION=$CODENAME-20200514 ;;
    trusty) DIST=ubuntu VERSION=$CODENAME-20201217 ;;
    *) echo >&2 "$CODENAME: unknown codename"; exit 1 ;;
esac

case $DIST in
    debian) BASE=debian:$VERSION-slim ARCHES="amd64 armv7 arm64" ;;
    ubuntu) BASE=ubuntu:$VERSION ARCHES=amd64 ;;
esac

function + {
    echo "$@"
    "$@"
}

MANIFESTS=""
for ARCH in $ARCHES; do
    TAG="$VERSION-$REVISION-$ARCH"
    + docker build \
        --platform linux/$ARCH \
        --build-arg BASE="$BASE" \
        --build-arg BUILDDATE="$BUILD_DATE" \
        --build-arg VERSION="$VERSION-$REVISION" \
        --build-arg TITLE="$TITLE" \
        --tag "$TITLE:$TAG" \
        .
    + docker push "$TITLE:$TAG"
    MANIFESTS="$MANIFESTS $TITLE:$TAG"
done
for TAG in $CODENAME $VERSION $VERSION-$REVISION; do
    + docker manifest create --amend "$TITLE:$TAG" $MANIFESTS
    + docker manifest push "$TITLE:$TAG"
done
