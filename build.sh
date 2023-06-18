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

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER")\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

pkg_install "$CONTAINER" \
    bind

cmd buildah run "$CONTAINER" -- \
    chmod 644 "/etc/named.conf"

echo + "rm -f …/var/named/{127.0.0,localhost.ip6,localhost}.zone" >&2
rm -f "$MOUNT/var/named/127.0.0.zone" \
    "$MOUNT/var/named/localhost.ip6.zone" \
    "$MOUNT/var/named/localhost.zone"

pkg_install "$CONTAINER" \
    inotify-tools

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

user_changeuid "$CONTAINER" named 65536

user_add "$CONTAINER" ssl-certs 65537

cmd buildah run "$CONTAINER" -- \
    usermod -aG ssl-certs named

cmd buildah run "$CONTAINER" -- \
    chown named:named \
        "/var/named/" \
        "/run/named/"

VERSION="$(pkg_version "$CONTAINER" bind)"

cleanup "$CONTAINER"

cmd buildah config \
    --port "53/udp" \
    --port "53/tcp" \
    --port "853/tcp" \
    "$CONTAINER"

cmd buildah config \
    --volume "/var/named" \
    --volume "/etc/named/local-zones" \
    --volume "/etc/named/ssl" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/named" \
    --entrypoint '[ "/entrypoint.sh" ]' \
    --cmd '[ "named", "-g", "-u", "named" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="Bind" \
    --annotation org.opencontainers.image.description="A container running ISC's BIND 9 DNS server." \
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/bind" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
