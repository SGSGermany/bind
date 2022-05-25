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
shopt -s nullglob

cmd() {
    echo + "$@"
    "$@"
    return $?
}

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[ -f "$BUILD_DIR/../container.env" ] && source "$BUILD_DIR/../container.env" \
    || { echo "ERROR: Container environment not found" >&2; exit 1; }

readarray -t -d' ' TAGS < <(printf '%s' "$BASE_TAGS")
DEFAULT_TAG="${DEFAULT_TAGS%% *}"

echo + "CONTAINER=\"\$(buildah from $IMAGE:$DEFAULT_TAG)\""
CONTAINER="$(buildah from "$IMAGE:$DEFAULT_TAG")"

echo + "MOUNT=\"\$(buildah mount $CONTAINER)\""
MOUNT="$(buildah mount "$CONTAINER")"

cmd buildah run "$CONTAINER" -- \
    pacman -S --noconfirm inotify-tools

echo + "rsync -v -rl --exclude .gitignore ./src/ …/"
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

cmd buildah run "$CONTAINER" -- \
    groupadd -g 65537 ssl-certs

cmd buildah run "$CONTAINER" -- \
    useradd -u 65537 -g ssl-certs -s "/sbin/nologin" -d "/" -M ssl-certs

cmd buildah run "$CONTAINER" -- \
    usermod -aG ssl-certs named

cmd buildah config --port "853/tcp" "$CONTAINER"

cmd buildah config \
    --volume "/etc/named-" \
    --volume "/etc/named/local-zones" \
    --volume "/etc/named/ssl" \
    "$CONTAINER"

cmd buildah config \
    --workingdir "/var/named" \
    --entrypoint '[ "/entrypoint.sh" ]' \
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
    --annotation org.opencontainers.image.base.name="$REGISTRY/$OWNER/$IMAGE:$DEFAULT_TAG" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$IMAGE:$DEFAULT_TAG")" \
    "$CONTAINER"

cmd buildah commit "$CONTAINER" "$IMAGE:${TAGS[0]}"
cmd buildah rm "$CONTAINER"

for TAG in "${TAGS[@]:1}"; do
    cmd buildah tag "$IMAGE:${TAGS[0]}" "$IMAGE:$TAG"
done
