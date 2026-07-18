-- V5: Add external download URL columns to releases table.
-- These columns are used when the release provides external download links
-- (e.g. GitHub / Gitee) instead of self-hosted packages.

ALTER TABLE releases
  ADD COLUMN IF NOT EXISTS github_download_url VARCHAR(1024);

ALTER TABLE releases
  ADD COLUMN IF NOT EXISTS gitee_download_url  VARCHAR(1024);
