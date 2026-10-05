# Database backup (no object storage)

* `pg_backup.sh` — nightly `pg_dump -Fc` → `age` → `/backups` (keep 14) → `rsync` over SSH to a second server (keep 30).
* `pg_restore.sh` — decrypt and restore into an empty database.
* The compose service `backup` runs it at 02:30 (container time) and exposes the age of the last success to Prometheus
  through the node-style file `/backups/.last_success` (see `../prometheus/rules.yml`).

## One-time setup
```bash
age-keygen -o age-key.txt          # keep this file OFFLINE (password manager / USB), never on the server
grep 'public key' age-key.txt      # → AGE_RECIPIENT=age1…  in .env
ssh-keygen -t ed25519 -f offsite_key   # authorise it on the 2nd server; mount as OFFSITE_SSH_KEY
```

## Restore test (do monthly; record the time in the release checklist)
```bash
createdb app_restore
AGE_IDENTITY=age-key.txt PGDATABASE=app_restore ./pg_restore.sh /backups/app-<stamp>.dump.age
psql app_restore -c 'select count(*) from users'
```
Without the age private key a backup cannot be read — losing it means losing the backups.
