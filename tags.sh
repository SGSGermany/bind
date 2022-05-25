#!/bin/bash
# Bind
# A container of ISC's BIND 9 DNS server.
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/container.env" ] && source "$BUILD_DIR/container.env" \
    || { echo "ERROR: Container environment not found" >&2; exit 1; }

IMAGE_ID="$(podman pull "$BASE_IMAGE" || true)"
if [ -z "$IMAGE_ID" ]; then
    echo "Failed to pull image '$BASE_IMAGE': No image with this tag found" >&2
    exit 1
fi

BIND_VERSION="$(podman run -i --rm "$IMAGE_ID" pacman -Syi bind \
    | sed -ne 's/^Version\s*: \(.*\)$/\1/p')"
if [ -z "$BIND_VERSION" ]; then
    echo "Unable to read version of the 'bind' Pacman package: Package not found" >&2
    exit 1
elif ! [[ "$BIND_VERSION" =~ ^([0-9]+:)?([0-9]+)\.([0-9]+)\.([0-9]+)([+~-]|$) ]]; then
    echo "Unable to read version of the 'bind' Pacman package: '$BIND_VERSION' is no valid version" >&2
    exit 1
fi

BIND_VERSION="${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"
BIND_VERSION_MINOR="${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
BIND_VERSION_MAJOR="${BASH_REMATCH[2]}"

TAG_DATE="$(date -u +'%Y%m%d%H%M')"

DEFAULT_TAGS=(
    "v$BIND_VERSION-default" "v$BIND_VERSION-default_$TAG_DATE"
    "v$BIND_VERSION_MINOR-default" "v$BIND_VERSION_MINOR-default_$TAG_DATE"
    "v$BIND_VERSION_MAJOR-default" "v$BIND_VERSION_MAJOR-default_$TAG_DATE"
    "latest-default"
)

BASE_TAGS=(
    "v$BIND_VERSION" "v${BIND_VERSION}_$TAG_DATE"
    "v$BIND_VERSION_MINOR" "v${BIND_VERSION_MINOR}_$TAG_DATE"
    "v$BIND_VERSION_MAJOR" "v${BIND_VERSION_MAJOR}_$TAG_DATE"
    "latest"
)

printf 'VERSION="%s"\n' "$BIND_VERSION"
printf 'DEFAULT_TAGS="%s"\n' "${DEFAULT_TAGS[*]}"
printf 'BASE_TAGS="%s"\n' "${BASE_TAGS[*]}"
