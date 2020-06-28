#!/bin/bash

set -o errexit
set -o nounset

if [[ $# != 2 ]]; then
    echo >&2 "usage: ./build.sh debian CODENAME"
    echo >&2 "                  ubuntu CODENAME"
    exit 64
fi

TITLE=arescentral/deb
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VERSION=1.0.0

DISTRIBUTION=$1
CODENAME=$2

docker build \
    --build-arg BASE="$DISTRIBUTION:$CODENAME" \
    --build-arg DISTRIBUTION="$DISTRIBUTION" \
    --build-arg BUILDDATE="$BUILD_DATE" \
    --build-arg VERSION="$VERSION" \
    --build-arg TITLE="$TITLE" \
    -t "$TITLE:$CODENAME" \
    -t "$TITLE:$CODENAME-$VERSION" \
    .
