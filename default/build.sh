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

cmd() {
    echo + "$@"
    "$@"
    return $?
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/../container.env" ] && source "$BUILD_DIR/../container.env" \
    || { echo "ERROR: Container environment not found" >&2; exit 1; }

readarray -t -d' ' TAGS < <(printf '%s' "$DEFAULT_TAGS")

echo + "CONTAINER=\"\$(buildah from $BASE_IMAGE)\""
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $CONTAINER)\""
MOUNT="$(buildah mount "$CONTAINER")"

cmd buildah run "$CONTAINER" -- \
    pacman -S --noconfirm bind

cmd buildah run "$CONTAINER" -- \
    chmod 644 "/etc/named.conf"

echo + "rm -f …/var/named/{127.0.0,localhost.ip6,localhost}.zone"
rm -f "$MOUNT/var/named/127.0.0.zone" \
    "$MOUNT/var/named/localhost.ip6.zone" \
    "$MOUNT/var/named/localhost.zone"

echo + "rsync -v -rl --exclude .gitignore ./src/ …/"
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

echo + "OLD_BIND_UID=\"\$(grep ^named: …/etc/passwd | cut -d: -f3)\""
OLD_BIND_UID="$(grep ^named: "$MOUNT/etc/passwd" | cut -d: -f3)"

echo + "OLD_BIND_GID=\"\$(grep ^named: …/etc/group | cut -d: -f3)\""
OLD_BIND_GID="$(grep ^named: "$MOUNT/etc/group" | cut -d: -f3)"

cmd buildah run "$CONTAINER" -- \
    usermod -u 65536 -s "/sbin/nologin" -d "/var/named" named

cmd buildah run "$CONTAINER" -- \
    groupmod -g 65536 named

cmd buildah run "$CONTAINER" -- \
    find / -path /sys -prune -o -path /proc -prune -o -user "$OLD_BIND_UID" -exec chown named -h {} \;

cmd buildah run "$CONTAINER" -- \
    find / -path /sys -prune -o -path /proc -prune -o -group "$OLD_BIND_GID" -exec chgrp named -h {} \;

cmd buildah run "$CONTAINER" -- \
    chown named:named "/var/named/"

cmd buildah config \
    --port "53/udp" \
    --port "53/tcp" \
    "$CONTAINER"

cmd buildah config \
    --volume "/etc/named" \
    --volume "/var/named" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/named" \
    --cmd '[ "named", "-g", "-u", "named" ]' \
    "$CONTAINER"

echo + "BIND_VERSION=\"\$(buildah run $CONTAINER -- named -v | sed -ne 's/^BIND \([^ ]*\).*$/\1/p')\""
BIND_VERSION="$(buildah run "$CONTAINER" -- named -v | sed -ne 's/^BIND \([^ ]*\).*$/\1/p')"

cmd buildah config \
    --annotation org.opencontainers.image.title="Bind" \
    --annotation org.opencontainers.image.description="A container of ISC's BIND 9 DNS server." \
    --annotation org.opencontainers.image.version="$BIND_VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/bind" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

cmd buildah commit "$CONTAINER" "$IMAGE:${TAGS[0]}"
cmd buildah rm "$CONTAINER"

for TAG in "${TAGS[@]:1}"; do
    cmd buildah tag "$IMAGE:${TAGS[0]}" "$IMAGE:$TAG"
done
