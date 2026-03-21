-- ============================================================
-- RoadNirman — Migration: Add missing columns to existing tables
-- Run this AFTER schema.sql if tables already existed
-- ============================================================

-- Add missing columns to complaints (IF NOT EXISTS prevents errors if already there)
DO $$
BEGIN
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
CREATE INDEX IF NOT EXISTS idx_complaints_coords ON complaints (lat, lng);
CREATE INDEX IF NOT EXISTS idx_complaints_ward   ON complaints (ward);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints (status);
