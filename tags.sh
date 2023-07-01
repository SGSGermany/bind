#!/bin/bash
# Bind
# A container running ISC's BIND 9 DNS server.
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

set -eu -o pipefail
export LC_ALL=C.UTF-8

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

BUILD_INFO=""
if [ $# -gt 0 ] && [[ "$1" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    BUILD_INFO=".${1,,}"
fi

# pull base image
echo + "IMAGE_ID=\"\$(podman pull $(quote "$BASE_IMAGE"))\"" >&2
IMAGE_ID="$(podman pull "$BASE_IMAGE" || true)"

if [ -z "$IMAGE_ID" ]; then
    echo "Failed to pull image '$BASE_IMAGE': No image with this tag found" >&2
    exit 1
fi

# get version of package
echo + "VERSION=\"\$(podman run -i --rm $(quote "$IMAGE_ID")" \
    "apk search --no-cache --exact bind" \
    "| sed -ne 's/^bind-\(.*\)$/\1/p')\"" >&2

VERSION="$(podman run -i --rm "$IMAGE_ID" \
    apk search --no-cache --exact bind \
    | sed -ne 's/^bind-\(.*\)$/\1/p')"

if [ -z "$VERSION" ]; then
    echo "Unable to read version of the 'bind' Alpine package: Package not found" >&2
    exit 1
elif ! [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)([+~-]|$) ]]; then
    echo "Unable to read version of the 'bind' Alpine package: '$VERSION' is no valid version" >&2
    exit 1
fi

VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
VERSION_MINOR="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
VERSION_MAJOR="${BASH_REMATCH[1]}"

# build tags
BUILD_INFO="$(date --utc +'%Y%m%d')$BUILD_INFO"

TAGS=(
    "v$VERSION" "v$VERSION-$BUILD_INFO"
    "v$VERSION_MINOR" "v$VERSION_MINOR-$BUILD_INFO"
    "v$VERSION_MAJOR" "v$VERSION_MAJOR-$BUILD_INFO"
    "latest"
)

printf 'VERSION="%s"\n' "$VERSION"
printf 'TAGS="%s"\n' "${TAGS[*]}"
