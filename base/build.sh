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
source "$BUILD_DIR/../container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$BASE_TAGS")
DEFAULT_TAG="${DEFAULT_TAGS%% *}"

echo + "CONTAINER=\"\$(buildah from $(quote "$IMAGE:$DEFAULT_TAG"))\"" >&2
CONTAINER="$(buildah from "$IMAGE:$DEFAULT_TAG")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER")\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

pkg_install "$CONTAINER" inotify-tools

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

user_add "$CONTAINER" ssl-certs 65537

cmd buildah run "$CONTAINER" -- \
    usermod -aG ssl-certs named

cleanup "$CONTAINER"

cmd buildah config \
    --port "853/tcp" \
    "$CONTAINER"

cmd buildah config \
    --volume "/etc/named-" \
    --volume "/etc/named/local-zones" \
    --volume "/etc/named/ssl" \
    "$CONTAINER"

cmd buildah config \
    --entrypoint '[ "/entrypoint.sh" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.base.name="$REGISTRY/$OWNER/$IMAGE:$DEFAULT_TAG" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$IMAGE:$DEFAULT_TAG")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
