#!/usr/bin/env bash
# installcheck.sh <node> - install the node's kit, verify it, build and run a
# clang program against the installed library, run xmllint from it, and remove
# it again.  This changes the system while it runs (PCSI database,
# SYS$COMMON:[LIBXML2], LIBXML2$ROOT); run kit.sh first.
# Output: out/install-<node>.txt.
set -euo pipefail
top=$(cd "$(dirname "$0")/.." && pwd)
node=${1:?usage: installcheck.sh <node>}
. "$top/upstream.conf"
REMOTE=$(echo "$UPSTREAM_NAME-$UPSTREAM_VERSION" | tr . _ | tr a-z A-Z)
"$top/tools/vms.sh" "$node" put "$top/tools/vms_installcheck.com" >/dev/null
read -r _ _ _ _ _ WORKDIR _ < <(awk -v n="$node" '$1==n' "$top/tools/nodes.conf")
mkdir -p "$top/out"
log=$top/out/install-$node.txt
job=$top/cache/installcheck-$node.com
printf '$ set noon\n$ @%sVMS_INSTALLCHECK.COM %s\n' "$WORKDIR" "$REMOTE" > "$job"
VMS_TIMEOUT=1800 "$top/tools/vms.sh" "$node" run "$job" > "$log" 2>&1
grep -aE 'install status|Installed|startup procedure|KIT_TEST:|XMLLINT:|SUCREMOVE|after removal|items found' "$log"
grep -aq 'KIT_TEST: PASS' "$log" &&
    grep -aq 'XMLLINT: PASS' "$log" &&
    grep -aq 'LIBXML2\$ROOT after removal: \[\]' "$log" &&
    grep -aq 'files after removal: \[\]' "$log" &&
    grep -aq 'startup after removal: \[\]' "$log"
