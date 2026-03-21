-- ============================================================
-- RoadNirman — Migration: Add missing columns to existing tables
-- Run this AFTER schema.sql if tables already existed
--
-- Phase 2 (legacy DB rename): aligns old column names with Flutter/Supabase client:
--   lat → latitude, lng → longitude, ward → ward_zone,
--   submitted_date → created_at
-- Idempotent: only renames when source exists and target does not (avoids duplicate
--   column errors if schema was partially migrated).
-- ============================================================

-- Add missing columns to complaints (IF NOT EXISTS prevents errors if already there)
DO $$
BEGIN
  -- Rename legacy columns to match spec (idempotent)
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'lat')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'latitude') THEN
    ALTER TABLE complaints RENAME COLUMN lat TO latitude;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'lng')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'longitude') THEN
    ALTER TABLE complaints RENAME COLUMN lng TO longitude;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'ward')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'ward_zone') THEN
    ALTER TABLE complaints RENAME COLUMN ward TO ward_zone;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'submitted_date')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'created_at') THEN
    ALTER TABLE complaints RENAME COLUMN submitted_date TO created_at;
  END IF;

  -- Core columns that may be missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'priority_score') THEN
    ALTER TABLE complaints ADD COLUMN priority_score FLOAT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'epdo_score') THEN
    ALTER TABLE complaints ADD COLUMN epdo_score FLOAT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'severity_score') THEN
    ALTER TABLE complaints ADD COLUMN severity_score FLOAT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'before_images') THEN
    ALTER TABLE complaints ADD COLUMN before_images TEXT[];
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'after_images') THEN
    ALTER TABLE complaints ADD COLUMN after_images TEXT[];
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'ssim_score') THEN
    ALTER TABLE complaints ADD COLUMN ssim_score FLOAT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'verification_status') THEN
    ALTER TABLE complaints ADD COLUMN verification_status TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'verification_hash') THEN
    ALTER TABLE complaints ADD COLUMN verification_hash TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'total_potholes') THEN
    ALTER TABLE complaints ADD COLUMN total_potholes INT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'reported_by_user_id') THEN
    ALTER TABLE complaints ADD COLUMN reported_by_user_id UUID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'created_by') THEN
    ALTER TABLE complaints ADD COLUMN created_by UUID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'sla_deadline') THEN
    ALTER TABLE complaints ADD COLUMN sla_deadline TIMESTAMPTZ;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'created_at') THEN
    ALTER TABLE complaints ADD COLUMN created_at TIMESTAMPTZ DEFAULT now();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'updated_at') THEN
    ALTER TABLE complaints ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now();
  END IF;

  -- Columns that may be missing in user_roles
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_roles' AND column_name = 'ward_zone') THEN
    ALTER TABLE user_roles ADD COLUMN ward_zone TEXT;
  END IF;

  -- Columns that may be missing in profiles
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'ward_zone') THEN
    ALTER TABLE profiles ADD COLUMN ward_zone TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'full_name') THEN
    ALTER TABLE profiles ADD COLUMN full_name TEXT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'ai_source') THEN
    ALTER TABLE complaints ADD COLUMN ai_source TEXT DEFAULT 'UNKNOWN';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'complaints' AND column_name = 'location_is_approximate') THEN
    ALTER TABLE complaints ADD COLUMN location_is_approximate BOOLEAN DEFAULT FALSE;
  END IF;
END $$;

-- Create indices if missing
CREATE INDEX IF NOT EXISTS idx_complaints_coords ON complaints (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_complaints_ward   ON complaints (ward_zone);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints (status);

-- Standardize status values to documented lifecycle
UPDATE complaints SET status = 'Open' WHERE status = 'New';
UPDATE complaints SET status = 'InProgress' WHERE status = 'In Progress';
UPDATE complaints SET status = 'PendingCEApproval' WHERE status IN ('Pending CE Authorization', 'Pending CE Approval');
