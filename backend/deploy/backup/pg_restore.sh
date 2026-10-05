#!/usr/bin/env bash
# Restore an encrypted backup into an EMPTY database.
# Usage: AGE_IDENTITY=/secure/age-key.txt pg_restore.sh <file.dump.age>   (libpq env selects the target DB)
set -euo pipefail
file="${1:?usage: pg_restore.sh <backup.dump.age>}"
: "${AGE_IDENTITY:?AGE_IDENTITY (private key file) is required}"
age -d -i "$AGE_IDENTITY" "$file" | pg_restore --no-owner --exit-on-error -d "${PGDATABASE:-app}"
echo "restore finished"
