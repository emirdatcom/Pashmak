#!/usr/bin/env bash
# Nightly Postgres backup without object storage (decision D-3):
#   pg_dump -Fc  →  age (public-key) encryption  →  local volume (keep 14)  →  rsync over SSH to a 2nd Iranian server (keep 30).
# Env: PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE (libpq), BACKUP_DIR, AGE_RECIPIENT (age1…),
#      OFFSITE_TARGET (user@host:/path, empty = skip), OFFSITE_SSH_KEY, KEEP_LOCAL (14), KEEP_OFFSITE (30),
#      SUCCESS_FILE (touched on success; the alert rule "no backup last night" reads its age).
set -euo pipefail

: "${AGE_RECIPIENT:?AGE_RECIPIENT is required (public key; the private key is NOT kept on this server)}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
KEEP_LOCAL="${KEEP_LOCAL:-14}"
KEEP_OFFSITE="${KEEP_OFFSITE:-30}"
SUCCESS_FILE="${SUCCESS_FILE:-$BACKUP_DIR/.last_success}"
stamp="$(date -u +%Y-%m-%dT%H%M%SZ)"
out="$BACKUP_DIR/${PGDATABASE:-app}-$stamp.dump.age"
tmp="$out.partial"

mkdir -p "$BACKUP_DIR"
trap 'rm -f "$tmp"' EXIT

pg_dump -Fc | age -r "$AGE_RECIPIENT" -o "$tmp"
[ -s "$tmp" ] || { echo "backup is empty" >&2; exit 1; }
mv "$tmp" "$out"
echo "backup written: $(basename "$out") ($(du -h "$out" | cut -f1))"

# local retention
ls -1t "$BACKUP_DIR"/*.dump.age 2>/dev/null | tail -n +"$((KEEP_LOCAL + 1))" | xargs -r rm -f --

# offsite copy + retention
if [ -n "${OFFSITE_TARGET:-}" ]; then
  ssh_cmd="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new ${OFFSITE_SSH_KEY:+-i $OFFSITE_SSH_KEY}"
  rsync -a -e "$ssh_cmd" "$out" "${OFFSITE_TARGET}/"
  host="${OFFSITE_TARGET%%:*}"; path="${OFFSITE_TARGET#*:}"
  # shellcheck disable=SC2029
  $ssh_cmd "$host" "ls -1t '$path'/*.dump.age 2>/dev/null | tail -n +$((KEEP_OFFSITE + 1)) | xargs -r rm -f --"
  echo "offsite copy done"
else
  echo "OFFSITE_TARGET not set: offsite copy skipped (a second disk/server is strongly recommended)" >&2
fi

touch "$SUCCESS_FILE"
# node-exporter textfile collector (alert rule BackupMissing)
if [ -n "${TEXTFILE_DIR:-}" ]; then
  printf "backup_last_success_timestamp_seconds %s\n" "$(date +%s)" > "$TEXTFILE_DIR/pg_backup.prom.tmp" && mv "$TEXTFILE_DIR/pg_backup.prom.tmp" "$TEXTFILE_DIR/pg_backup.prom"
fi
