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
source "$CI_TOOLS_PATH/helper/common-traps.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"
source "$CI_TOOLS_PATH/helper/chkconf.sh.inc"

chkconf_clean() {
    sed -e 's|//|#|g' -e 's/^\([^#]*\)#.*$/\1/' -e '/^\s*$/d' "$1" > "$2"
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

[ -d "$BUILD_DIR/base-conf" ] \
    || { echo "Invalid base configuration directory '$BUILD_DIR/base-conf': No such directory" >&2; exit 1; }

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

trap_exit buildah rm "$CONTAINER"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

pkg_install "$CONTAINER" bind

echo + "CHKCONF_DIR=\"\$(mktemp -d)\"" >&2
CHKCONF_DIR="$(mktemp -d)"

trap_exit rm -rf "$CHKCONF_DIR"

chkconf_prepare \
    --local "$BUILD_DIR/base-conf" "./base-conf" \
    "$CHKCONF_DIR" "/tmp/…" \
    "named.conf.authoritative" "named.conf.authoritative" \
    "named.conf.recursive" "named.conf.recursive" \
    "localhost.zone" "localhost.zone" \
    "127.zone" "127.zone"

chkconf_prepare \
    --upstream "$MOUNT" "…" \
    "$CHKCONF_DIR" "/tmp/…" \
    "etc/bind/named.conf.authoritative" "named.conf.authoritative" \
    "etc/bind/named.conf.recursive" "named.conf.recursive" \
    "var/bind/pri/localhost.zone" "localhost.zone" \
    "var/bind/pri/127.zone" "127.zone"

chkconf_diff "$CHKCONF_DIR" "/tmp/…"
