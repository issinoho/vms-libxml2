#!/usr/bin/env bash
# prepare.sh - build a VMS-ready libxml2 source tree in staging/<name>-<version>/
#
#   1. fetch + verify the upstream tarball
#   2. extract it, apply patches/series, lay overlay/ over the top
#   3. generate include/libxml/xmlversion.h (the feature switches) by running
#      upstream's configure on this host with XML_OPTIONS from upstream.conf;
#      it holds only LIBXML_*_ENABLED and version defines, no host facts.
#      The VMS config.h is ours (overlay/vmsport/config.h).
#
# Nothing in staging/ is ever edited by hand: fix things in patches/ or overlay/.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"
name=$UPSTREAM_NAME-$UPSTREAM_VERSION
tarball=$top/cache/$(basename "$UPSTREAM_URL")
stage=$top/staging/$name

step() { echo "prepare: $*"; }
die() { echo "prepare: error: $*" >&2; exit 1; }

"$top/tools/fetch.sh" >/dev/null

step "extracting $name"
rm -rf "$stage"; mkdir -p "$top/staging"
tar -xJf "$tarball" -C "$top/staging"
[ -d "$stage" ] || die "tarball did not unpack to $stage"

while read -r p; do
    case $p in ''|'#'*) continue ;; esac
    step "patch $p"
    patch -d "$stage" -p1 -s --no-backup-if-mismatch -F0 < "$top/patches/$p" ||
        die "patch $p does not apply cleanly"
done < "$top/patches/series"

# overlay/ may only add files; changes to upstream files belong in patches/.
(cd "$top/overlay" && find . -type f) | while read -r f; do
    [ -e "$stage/$f" ] && die "overlay/$f would replace an upstream file; use a patch"
    true
done
cp -a "$top/overlay/." "$stage/"

step "xmlversion.h ($XML_OPTIONS)"
conf=$top/cache/hostconf
rm -rf "$conf"; mkdir -p "$conf"
tar -xJf "$tarball" -C "$conf"
# shellcheck disable=SC2086
( cd "$conf/$name" && ./configure $XML_OPTIONS > ../configure.log 2>&1 ) ||
    die "host configure failed (cache/hostconf/configure.log)"
cp "$conf/$name/include/libxml/xmlversion.h" "$stage/include/libxml/xmlversion.h"
grep -q "LIBXML_DOTTED_VERSION \"$UPSTREAM_VERSION\"" "$stage/include/libxml/xmlversion.h" ||
    die "xmlversion.h does not carry version $UPSTREAM_VERSION"

printf 'VERSION=%s\nKIT_VERSION=%s-vms%s\n' "$UPSTREAM_VERSION" "$UPSTREAM_VERSION" \
    "$VMS_PATCH_LEVEL" > "$stage/vmsport/version.env"

# --- PCSI kit inputs (vmsport/kit/MAKE_KIT.COM builds the kit on the node) --
step "PCSI kit inputs"
kit=$stage/vmsport/kit
: "${KIT_PRODUCER:=ISSINOHO}"
# libxml2 versions have three parts (2.15.4): the third is the PCSI update and
# our VMS patch level the ECO, as in vms-zlib, so 2.15.4-vms1 is V2.15-4E1.
IFS=. read -r major minor update _ <<< "$UPSTREAM_VERSION"
pcsiversion="V$major.$minor-${update:-0}E$VMS_PATCH_LEVEL"
kitversion="$UPSTREAM_VERSION-vms$VMS_PATCH_LEVEL"
headers=$(cd "$stage/include/libxml" && ls *.h | tr a-z A-Z |
          sed 's|^|    file [LIBXML2.INCLUDE.LIBXML]|; s|$| ;|')
subst() {
    sed -e "s/@PRODUCER@/$KIT_PRODUCER/g" -e "s/@BASE@/$1/g" \
        -e "s/@PCSIVERSION@/$pcsiversion/g" -e "s/@VERSION@/$UPSTREAM_VERSION/g" \
        -e "s/@KITVERSION@/$kitversion/g" -e "s/@ARCH@/$2/g"
}
subst X86VMS "" < "$kit/libxml2.pcsi\$desc_template" |
    awk -v h="$headers" '$0 == "@HEADERS@" { print h; next } { print }' > "$kit/LIBXML2-X86VMS.PCSI\$DESC"
subst X86VMS "" < "$kit/libxml2.pcsi\$text_template" > "$kit/LIBXML2-X86VMS.PCSI\$TEXT"
rm -f "$kit/libxml2.pcsi\$desc_template" "$kit/libxml2.pcsi\$text_template"
subst "" "x86-64" < "$kit/readme.vms" > "$kit/README.VMS"; rm -f "$kit/readme.vms"
mkdir -p "$kit/doc"
cp "$stage/Copyright" "$kit/doc/COPYRIGHT."
cp "$stage/NEWS" "$kit/doc/NEWS."
cp "$stage/README.md" "$kit/doc/README.MD"
printf 'KIT_PRODUCER=%s\nPCSI_VERSION=%s\nKIT_VERSION=%s\n' "$KIT_PRODUCER" "$pcsiversion" \
    "$kitversion" > "$kit/kit.env"
step "staged $stage"
