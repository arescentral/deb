#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

if [[ -n "${DRONE_TAG-}" ]]; then
  XYZ=$${DRONE_TAG#v}
  XY=$${XYZ%%.*}
  X=$${XY%%.*}
  tee $1 <<EOF
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
  tee $1 <<EOF
HEAD-$ARCH,
HEAD-$DATE-$ARCH
EOF
fi
