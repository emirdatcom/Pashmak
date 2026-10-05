-- +goose Up
-- Decision D-3: no object storage. Backups live in the row only.
DELETE FROM backups WHERE blob IS NULL;
ALTER TABLE backups DROP COLUMN storage;
ALTER TABLE backups DROP COLUMN blob_ref;
ALTER TABLE backups ALTER COLUMN blob SET NOT NULL;

-- +goose Down
ALTER TABLE backups ALTER COLUMN blob DROP NOT NULL;
ALTER TABLE backups ADD COLUMN blob_ref text NOT NULL DEFAULT '';
ALTER TABLE backups ADD COLUMN storage text NOT NULL DEFAULT 'db' CHECK (storage IN ('db', 's3'));
