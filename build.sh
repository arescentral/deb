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
    debian) BASE=debian:$VERSION-slim PLATFORMS=linux/amd64,linux/arm/v7,linux/arm64 ;;
    ubuntu) BASE=ubuntu:$VERSION PLATFORMS=linux/amd64 ;;
esac

if [[ "$LOCAL" != "" ]]; then
    docker build \
        --build-arg BASE="$BASE" \
        --build-arg BUILDDATE="$BUILD_DATE" \
        --build-arg VERSION="$VERSION-$REVISION" \
        --build-arg TITLE="$TITLE" \
        --tag "$TITLE:$CODENAME" \
        --tag "$TITLE:$VERSION" \
        --tag "$TITLE:$VERSION-$REVISION" \
        .
else
    docker buildx build \
        --push \
        --platform $PLATFORMS \
        --build-arg BASE="$BASE" \
        --build-arg BUILDDATE="$BUILD_DATE" \
        --build-arg VERSION="$VERSION-$REVISION" \
        --build-arg TITLE="$TITLE" \
        --tag "$TITLE:$CODENAME" \
        --tag "$TITLE:$VERSION" \
        --tag "$TITLE:$VERSION-$REVISION" \
        .
fi
