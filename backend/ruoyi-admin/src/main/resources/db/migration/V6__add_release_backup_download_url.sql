-- V6: Add backup external download URL column to releases table.
-- Used by the current manual-update flow together with GitHub / Gitee links.

ALTER TABLE releases
  ADD COLUMN IF NOT EXISTS backup_download_url VARCHAR(1024);
