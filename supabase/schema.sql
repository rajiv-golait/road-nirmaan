-- ============================================================
-- RoadNirman — Supabase Schema
-- Run this FIRST in the Supabase SQL Editor.
-- ============================================================

-- Enable uuid extension (normally already on in Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ──────────────────────────────────────
-- 1. profiles
-- ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      TEXT UNIQUE NOT NULL,
  full_name  TEXT,
  role       TEXT DEFAULT 'citizen',
  ward_zone  TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ──────────────────────────────────────
-- 2. user_roles
--    Pre-seeded by admin; looked up at login to assign role
-- ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_roles (
  id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  email     TEXT UNIQUE NOT NULL,
  role      TEXT NOT NULL DEFAULT 'citizen',
  ward_zone TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS user_roles_user_id_unique
  ON user_roles (user_id)
  WHERE user_id IS NOT NULL;

-- ──────────────────────────────────────
-- 3. complaints
--    Column names match complaint_service.dart mapAppToRow / mapRowToApp
-- ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS complaints (
  id                        TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
  title                     TEXT NOT NULL,
  description               TEXT,
  damage_type               TEXT,
  severity                  TEXT DEFAULT 'Medium',
  severity_score            FLOAT8,
  status                    TEXT DEFAULT 'Open',
  priority_score            FLOAT8,
  epdo_score                FLOAT8,

  -- Location
  latitude                  FLOAT8,
  longitude                 FLOAT8,
  location                  TEXT,         -- human-readable address
  ward_zone                 TEXT,

  -- Assignment
  assigned_to               TEXT,
  assigned_party_type       TEXT,
  work_gang                 TEXT,
  official_remarks          TEXT,

  -- Images (stored as text arrays)
  images                    TEXT[],
  before_images             TEXT[],
  after_images              TEXT[],

  -- AI / verification
  ssim_score                FLOAT8,
  verification_status       TEXT,
  verification_hash         TEXT,
  total_potholes            INT,
  ai_source                 TEXT DEFAULT 'UNKNOWN',
  location_is_approximate   BOOLEAN DEFAULT FALSE,

  -- Authoring
  reported_by               TEXT DEFAULT 'citizen',
  reported_by_user_id       UUID REFERENCES auth.users(id),
  created_by                UUID REFERENCES auth.users(id),
  upvotes                   INT DEFAULT 0,

  -- Escalation
  current_handler            TEXT DEFAULT 'JE',
  received_at_current_level  TIMESTAMPTZ,
  escalated_from             TEXT,
  auto_escalated_at          TIMESTAMPTZ,
  manually_escalated_at      TIMESTAMPTZ,
  sla_deadline               TIMESTAMPTZ,

  -- Timestamps
  created_at                 TIMESTAMPTZ DEFAULT now(),
  verified_date              TIMESTAMPTZ,
  last_update                TIMESTAMPTZ DEFAULT now(),
  updated_at                 TIMESTAMPTZ DEFAULT now()
);

-- Index for spatial bounding-box queries (dedup phase)
CREATE INDEX IF NOT EXISTS idx_complaints_coords ON complaints (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_complaints_ward   ON complaints (ward_zone);
CREATE INDEX IF NOT EXISTS idx_complaints_status ON complaints (status);

-- ──────────────────────────────────────
-- 4. complaint_votes
-- ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS complaint_votes (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  complaint_id  TEXT NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(complaint_id, user_id)
);

-- ──────────────────────────────────────
-- 5. complaint_events
-- ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS complaint_events (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  complaint_id    TEXT NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  event_type      TEXT NOT NULL,
  from_status     TEXT,
  to_status       TEXT,
  actor_user_id   UUID,
  actor_email     TEXT,
  actor_id        TEXT,       -- 'SYSTEM' for auto-escalation
  remarks         TEXT,
  notes           TEXT,
  metadata        JSONB,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_complaint ON complaint_events (complaint_id);

-- ──────────────────────────────────────
-- Auto-update updated_at trigger
-- ──────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_complaints_updated_at
  BEFORE UPDATE ON complaints
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
