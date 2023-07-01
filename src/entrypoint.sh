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
    # generate Diffie Hellman parameters, if necessary
    if [ ! -f "/etc/bind/ssl/dhparams.pem" ]; then
        # generating Diffie Hellman parameters might take a few minutes...
        printf "%s generating Diffie Hellman parameters\n" "$(LC_ALL=C date +'%d-%b-%Y %T.000')" >&2
        openssl dhparam -out "/etc/bind/ssl/dhparams.pem" 2048
    fi

    # start SSL certificate watchdog
    named-cert-watchdog &

    # re-create /etc/bind/named.conf.local-zones
    named-config-update

    exec "$@"
fi

exec "$@"
