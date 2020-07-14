#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if [[ -n "${DRONE_TAG-}" ]]; then
    XYZ=${DRONE_TAG#v}
    XY=${XYZ%.*}
    X=${XY%.*}
    SOURCE_TAG=$XYZ-$DATE
    OTHER_TAGS="tags:
  - $XY-$DATE
  - $X-$DATE
  - $XYZ
  - $XY
  - $X"
else
    SOURCE_TAG=latest-$DATE
    OTHER_TAGS="tags:
  - latest"
fi

tee $1 <<EOF
image: arescentral/deb-$CODENAME:$SOURCE_TAG
$OTHER_TAGS
manifests:
  - image: arescentral/deb-$CODENAME:$SOURCE_TAG-amd64
    platform:
      architecture: amd64
      os: linux
  - image: arescentral/deb-$CODENAME:$SOURCE_TAG-arm64
    platform:
      architecture: arm64
      os: linux
      variant: v8
  - image: arescentral/deb-$CODENAME:$SOURCE_TAG-arm
    platform:
      architecture: arm
      os: linux
      variant: v7
EOF
