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
export LC_ALL=C

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-archlinux.sh.inc"

source "$CI_TOOLS_PATH/helper/chkconf.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

[ -d "$BUILD_DIR/base-conf" ] \
    || { echo "Invalid base configuration directory '$BUILD_DIR/base-conf': No such directory" >&2; exit 1; }

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

pkg_install "$CONTAINER" bind

echo + "CHKCONF_DIR=\"\$(mktemp -d)\"" >&2
CHKCONF_DIR="$(mktemp -d)"

chkconf_prepare --local "$BUILD_DIR/base-conf" "$CHKCONF_DIR" \
    "named.conf" "named.conf" \
    "127.0.0.zone" "127.0.0.zone" \
    "localhost.zone" "localhost.zone" \
    "localhost.ip6.zone" "localhost.ip6.zone"

chkconf_prepare --upstream "$MOUNT" "$CHKCONF_DIR" \
    "etc/named.conf" "named.conf" \
    "var/named/127.0.0.zone" "127.0.0.zone" \
    "var/named/localhost.zone" "localhost.zone" \
    "var/named/localhost.ip6.zone" "localhost.ip6.zone"

chkconf_diff "$CHKCONF_DIR"

echo + "rm -rf /tmp/…" >&2
rm -rf "$CHKCONF_DIR"

cmd buildah rm "$CONTAINER"
