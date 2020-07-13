#!/bin/bash

if [[ -n "$DRONE_TAG" ]]; then
  XYZ=$${DRONE_TAG#v}
  XY=$${XYZ%%.*}
  X=$${XY%%.*}
  cat <<EOF
latest-$ARCH,
$XYZ-$ARCH,
$XY-$ARCH,
$X-$ARCH,
latest-$DATE-$ARCH,
$XYZ-$DATE-$ARCH,
$XY-$DATE-$ARCH,
$X-$DATE-$ARCH
EOF
else
  cat <<EOF
HEAD-$ARCH,
HEAD-$DATE-$ARCH
EOF
fi
