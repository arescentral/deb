#!/bin/bash

if [[ -n "$DRONE_TAG" ]]; then
    XYZ=${DRONE_TAG#v}
    XY=${XYZ%.*}
    X=${XY%.*}
    SOURCE_TAG="$XYZ-$DATE"
    FIRST_TAG=latest
    OTHER_TAGS="tags:
  - $XYZ,
  - $XY,
  - $X,
  - latest-$DATE,
  - $XYZ-$DATE,
  - $XY-$DATE,
  - $X-$DATE"
else
    SOURCE_TAG="HEAD-$DATE"
    FIRST_TAG=HEAD
    OTHER_TAGS="tags:
  - HEAD-$DATE"
fi

cat <<EOF
image: arescentral/deb-$CODENAME:$FIRST_TAG
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
