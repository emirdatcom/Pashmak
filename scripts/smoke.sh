#!/usr/bin/env bash
# Production/staging smoke test: health, config, content manifest, and that /metrics and /admin are NOT public.
# Usage: scripts/smoke.sh https://api.example.ir
set -euo pipefail
base="${1:?usage: smoke.sh <base-url>}"
fail=0
check() { # name expected-status actual-status
  if [ "$2" = "$3" ]; then echo "ok   $1 ($3)"; else echo "FAIL $1: expected $2 got $3"; fail=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@"; }
h=(-H 'X-App-Version: 1.0.0' -H 'X-Market: bazaar')

check healthz 200 "$(code "$base/healthz")"
check config 200 "$(code "${h[@]}" "$base/v1/config")"
check content-manifest 200 "$(code "${h[@]}" "$base/v1/content/manifest")"
check unauthenticated-me 401 "$(code "${h[@]}" "$base/v1/me")"
check admin-hidden 404 "$(code "$base/admin/v1/config")"
m=$(code "$base/metrics"); [ "$m" = 200 ] && { echo "FAIL /metrics is public"; fail=1; } || echo "ok   metrics not public ($m)"
exit $fail
