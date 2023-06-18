#!/bin/sh
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

set -e

if [ $# -eq 0 ]; then
    set -- named -g -u "named"
fi

if [ "$1" == "named" ]; then
    if [ ! -f "/etc/named/ssl/dhparams.pem" ]; then
        # generating Diffie Hellman parameters might take a few minutes...
        printf "%s generating Diffie Hellman parameters\n" "$(LC_ALL=C date +'%d-%b-%Y %T.000')" >&2
        openssl dhparam -out "/etc/named/ssl/dhparams.pem" 2048
    fi

    (
        set -eu -o pipefail -- /etc/named/ssl/*/
        if [ $# -eq 1 ] && [ "$1" == "/etc/named/ssl/*/" ] || [ $# -eq 0 ]; then
            printf "%s skipping cert watchdog service\n" \
                "$(LC_ALL=C date +'%d-%b-%Y %T.000')" >&2
            exit 0
        fi

        printf "%s starting cert watchdog service\n" \
            "$(LC_ALL=C date +'%d-%b-%Y %T.000')" >&2
        inotifywait -e close_write,delete,move -m "$@" \
            | while read -r DIRECTORY EVENTS FILENAME; do
                printf "%s cert watchdog: receiving inotify event '%s' for '%s%s'\n" \
                    "$(LC_ALL=C date +'%d-%b-%Y %T.000')" "$EVENTS" "$DIRECTORY" "$FILENAME" >&2

                # wait till 300 sec (5 min) after the last event, new events reset the timer
                while read -t 300 -r DIRECTORY EVENTS FILENAME; do
                    printf "%s cert watchdog: receiving inotify event '%s' for '%s%s'\n" \
                        "$(LC_ALL=C date +'%d-%b-%Y %T.000')" "$EVENTS" "$DIRECTORY" "$FILENAME" >&2
                done

                printf "%s cert watchdog: triggering configuration reload\n" \
                    "$(LC_ALL=C date +'%d-%b-%Y %T.000')" >&2
                named-reload
            done
    ) &

    # re-create /etc/named/named.conf.local-zones
    named-config-update

    exec "$@"
fi

exec "$@"
