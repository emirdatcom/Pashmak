#!/usr/bin/env bash
# Decision D-7: the Bazaar and Myket APKs must not share billing SDKs.
# Usage: tool/check_sdk_separation.sh <bazaar|myket> <path/to.apk>
# Looks for the other market's class descriptors in every classes*.dex and its permission/package in the
# manifest. Exit 1 = leak (CI red).
set -euo pipefail
flavor="${1:?flavor bazaar|myket}"; apk="${2:?apk path}"
case "$flavor" in
  bazaar) forbid_dex=('Lir/myket/' 'Lir/mservices/market/'); forbid_manifest=('ir.mservices.market' 'ir.myket'); require_manifest='com.farsitel.bazaar';;
  myket)  forbid_dex=('Lir/cafebazaar/' 'Lcom/farsitel/bazaar/' 'Lcom/android/vending/billing/'); forbid_manifest=('com.farsitel.bazaar' 'ir.cafebazaar'); require_manifest='ir.mservices.market';;
  *) echo "unknown flavor $flavor" >&2; exit 2;;
esac
fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
unzip -q -o "$apk" 'classes*.dex' AndroidManifest.xml -d "$tmp"

dex_strings="$tmp/dex.txt"
cat "$tmp"/classes*.dex | strings -n 6 > "$dex_strings"
for pat in "${forbid_dex[@]}"; do
  if grep -qF "$pat" "$dex_strings"; then echo "LEAK: $flavor APK contains classes matching $pat"; fail=1; fi
done

# Binary XML stores strings as UTF-16LE or UTF-8; try aapt2 first, fall back to strings in both encodings.
if command -v aapt2 >/dev/null 2>&1; then
  aapt2 dump xmltree --file AndroidManifest.xml "$apk" > "$tmp/manifest.txt"
else
  { strings -n 6 "$tmp/AndroidManifest.xml"; strings -n 6 -e l "$tmp/AndroidManifest.xml"; } > "$tmp/manifest.txt"
fi
for pat in "${forbid_manifest[@]}"; do
  if grep -qF "$pat" "$tmp/manifest.txt"; then echo "LEAK: $flavor manifest mentions $pat"; fail=1; fi
done
grep -qF "$require_manifest" "$tmp/manifest.txt" || { echo "MISSING: $flavor manifest lacks its own market ($require_manifest)"; fail=1; }

[ "$fail" = 0 ] && echo "ok: $flavor APK has only its own market SDK"
exit "$fail"
