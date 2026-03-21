-- ============================================================
-- RoadNirman — HARD RESET SCRIPT
-- RUN THIS FIRST TO WIPE OLD TABLES AND START FRESH
-- ============================================================

-- Drop the tables completely so we can recreate them with the correct schema
DROP TABLE IF EXISTS complaint_events CASCADE;
DROP TABLE IF EXISTS complaint_votes CASCADE;
DROP TABLE IF EXISTS complaints CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;

-- (We don't drop 'profiles' because it may be linked to your auth users,
--  instead we just make sure it has the new columns)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ward_zone TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
