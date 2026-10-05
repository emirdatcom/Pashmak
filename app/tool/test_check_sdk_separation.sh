#!/usr/bin/env bash
# Self-test for check_sdk_separation.sh with synthetic APKs (CI runs it before the real check).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mk() { # name dexstring manifeststring
  mkdir -p "$tmp/$1" && printf 'dex\n035\0%s\0padding-padding' "$2" > "$tmp/$1/classes.dex" && printf '<manifest>%s</manifest>' "$3" > "$tmp/$1/AndroidManifest.xml"
  (cd "$tmp/$1" && zip -q ../"$1".apk classes.dex AndroidManifest.xml)
}
mk good_bazaar 'Lir/cafebazaar/poolakey/Payment;' 'com.farsitel.bazaar'
mk leaky_bazaar 'Lir/cafebazaar/poolakey/Payment;Lir/myket/billingclient/IabHelper;' 'com.farsitel.bazaar'
mk leaky_manifest 'Lir/cafebazaar/poolakey/Payment;' 'com.farsitel.bazaar ir.mservices.market'
mk good_myket 'Lir/myket/billingclient/IabHelper;' 'ir.mservices.market'
mk leaky_myket 'Lir/myket/billingclient/IabHelper;Lir/cafebazaar/poolakey/Payment;' 'ir.mservices.market'
fail=0
expect() { # expected-exit flavor apk
  "$here/check_sdk_separation.sh" "$2" "$tmp/$3.apk" >/dev/null 2>&1; got=$?
  if [ "$got" = "$1" ]; then echo "ok   $3 ($2) → $got"; else echo "FAIL $3 ($2): expected $1 got $got"; fail=1; fi
}
expect 0 bazaar good_bazaar
expect 1 bazaar leaky_bazaar
expect 1 bazaar leaky_manifest
expect 0 myket good_myket
expect 1 myket leaky_myket
expect 1 myket good_bazaar   # the wrong market's APK is rejected both ways
exit $fail
