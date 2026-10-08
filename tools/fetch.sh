#!/usr/bin/env bash
# fetch.sh - download the libxml2 release tarball named in upstream.conf into
# cache/ and verify its SHA-256 (GNOME publishes no signature for libxml2).
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"

cache=$top/cache
mkdir -p "$cache"
tarball=$cache/$(basename "$UPSTREAM_URL")

[ -f "$tarball" ] || { echo "fetch: downloading $UPSTREAM_URL"
                       curl -fsSL -o "$tarball.tmp" "$UPSTREAM_URL"; mv "$tarball.tmp" "$tarball"; }
echo "$UPSTREAM_SHA256  $tarball" | sha256sum -c --quiet - ||
    { echo "fetch: SHA-256 mismatch for $tarball" >&2; exit 1; }
echo "fetch: SHA-256 OK"
echo "fetch: $tarball"
