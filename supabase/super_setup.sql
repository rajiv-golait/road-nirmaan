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
  email     TEXT UNIQUE NOT NULL,
  role      TEXT NOT NULL DEFAULT 'citizen',
  ward_zone TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

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
  status                    TEXT DEFAULT 'New',
  priority_score            FLOAT,
  epdo_score                FLOAT,

  -- Location
  lat                       DOUBLE PRECISION,
  lng                       DOUBLE PRECISION,
  location                  TEXT,         -- human-readable address
  ward                      TEXT,

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
  ssim_score                FLOAT,
  verification_status       TEXT,
  total_potholes            INT,

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
  submitted_date             TIMESTAMPTZ DEFAULT now(),
  verified_date              TIMESTAMPTZ,
  last_update                TIMESTAMPTZ DEFAULT now(),
  created_at                 TIMESTAMPTZ DEFAULT now(),
  updated_at                 TIMESTAMPTZ DEFAULT now()
);

-- Index for spatial bounding-box queries (dedup phase)
CREATE INDEX IF NOT EXISTS idx_complaints_coords ON complaints (lat, lng);
CREATE INDEX IF NOT EXISTS idx_complaints_ward   ON complaints (ward);
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


-- ============================================================
-- RoadNirman — Row Level Security (RLS) Policies
-- Run AFTER schema.sql
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints        ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_votes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_events  ENABLE ROW LEVEL SECURITY;

-- ──────────────────────────────────────
-- Helper: get current user's role from user_roles
-- ──────────────────────────────────────
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
  SELECT COALESCE(
    (SELECT role FROM user_roles
     WHERE email = (SELECT email FROM auth.users WHERE id = auth.uid())
     LIMIT 1),
    'citizen'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ──────────────────────────────────────
-- profiles
-- ──────────────────────────────────────
DROP POLICY IF EXISTS profiles_select_own ON profiles;
CREATE POLICY profiles_select_own ON profiles FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_update_own ON profiles;
CREATE POLICY profiles_update_own ON profiles FOR UPDATE USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_insert_own ON profiles;
CREATE POLICY profiles_insert_own ON profiles FOR INSERT WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS profiles_select_officials ON profiles;
CREATE POLICY profiles_select_officials ON profiles FOR SELECT USING (
  get_user_role() IN (
    'junior_engineer', 'assistant_engineer', 'deputy_engineer',
    'chief_engineer', 'additional_commissioner', 'commissioner'
  )
);

-- ──────────────────────────────────────
-- user_roles
-- ──────────────────────────────────────
DROP POLICY IF EXISTS user_roles_select ON user_roles;
CREATE POLICY user_roles_select ON user_roles FOR SELECT TO authenticated USING (true);

-- ──────────────────────────────────────
-- complaints
-- ──────────────────────────────────────
DROP POLICY IF EXISTS complaints_select_all ON complaints;
CREATE POLICY complaints_select_all ON complaints FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS complaints_insert_citizen ON complaints;
CREATE POLICY complaints_insert_citizen ON complaints FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS complaints_update_auth ON complaints;
CREATE POLICY complaints_update_auth ON complaints FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS complaints_delete_admin ON complaints;
CREATE POLICY complaints_delete_admin ON complaints FOR DELETE TO authenticated USING (
  get_user_role() IN ('commissioner', 'additional_commissioner')
);

-- ──────────────────────────────────────
-- complaint_votes
-- ──────────────────────────────────────
DROP POLICY IF EXISTS votes_select_own ON complaint_votes;
CREATE POLICY votes_select_own ON complaint_votes FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS votes_insert_own ON complaint_votes;
CREATE POLICY votes_insert_own ON complaint_votes FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS votes_delete_own ON complaint_votes;
CREATE POLICY votes_delete_own ON complaint_votes FOR DELETE TO authenticated USING (user_id = auth.uid());

-- ──────────────────────────────────────
-- complaint_events
-- ──────────────────────────────────────
DROP POLICY IF EXISTS events_select_all ON complaint_events;
CREATE POLICY events_select_all ON complaint_events FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS events_insert_auth ON complaint_events;
CREATE POLICY events_insert_auth ON complaint_events FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS events_delete_admin ON complaint_events;
CREATE POLICY events_delete_admin ON complaint_events FOR DELETE TO authenticated USING (
  get_user_role() IN ('commissioner', 'additional_commissioner')
);


-- ============================================================
-- RoadNirman — Storage Buckets
-- Run AFTER schema.sql
-- ============================================================

-- 1. complaint-images  —  public read, authenticated write
--    Used by StorageService for citizen photo uploads
INSERT INTO storage.buckets (id, name, public)
VALUES ('complaint-images', 'complaint-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public read
DROP POLICY IF EXISTS storage_complaint_images_public_read ON storage.objects;
CREATE POLICY storage_complaint_images_public_read ON storage.objects
  FOR SELECT USING (bucket_id = 'complaint-images');

-- Allow authenticated users to upload
DROP POLICY IF EXISTS storage_complaint_images_auth_write ON storage.objects;
CREATE POLICY storage_complaint_images_auth_write ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'complaint-images');

-- Allow users to update their own uploads
DROP POLICY IF EXISTS storage_complaint_images_auth_update ON storage.objects;
CREATE POLICY storage_complaint_images_auth_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'complaint-images' AND (auth.uid())::text = (storage.foldername(name))[2]);

-- Allow users to delete their own uploads
DROP POLICY IF EXISTS storage_complaint_images_auth_delete ON storage.objects;
CREATE POLICY storage_complaint_images_auth_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'complaint-images' AND (auth.uid())::text = (storage.foldername(name))[2]);


-- 2. verifications  —  authenticated read/write
--    Used for before/after repair photo comparison
INSERT INTO storage.buckets (id, name, public)
VALUES ('verifications', 'verifications', false)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users can read
DROP POLICY IF EXISTS storage_verifications_auth_read ON storage.objects;
CREATE POLICY storage_verifications_auth_read ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'verifications');

-- Authenticated users can upload
DROP POLICY IF EXISTS storage_verifications_auth_write ON storage.objects;
CREATE POLICY storage_verifications_auth_write ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'verifications');

-- Authenticated users can update own
DROP POLICY IF EXISTS storage_verifications_auth_update ON storage.objects;
CREATE POLICY storage_verifications_auth_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'verifications' AND (auth.uid())::text = (storage.foldername(name))[2]);


-- ============================================================
-- RoadNirman — Seed Data  (50 complaints across Solapur's 6 wards)
-- Run AFTER schema.sql
-- ============================================================
-- Solapur center: 17.6868° N, 75.9074° E
-- Ward zones: North, South, East, West, Central, Cantonment
-- Spread across ~15km radius

-- ──────────────────────────────────────
-- 1. Seed user_roles (officials)
-- ──────────────────────────────────────
INSERT INTO user_roles (email, role, ward_zone) VALUES
  ('commissioner@solapur.gov.in','commissioner',            NULL),
  ('ac@solapur.gov.in',          'assistant_commissioner',  NULL),
  ('chiefengineer@solapur.gov.in','chief_engineer',         NULL),
  ('cityengineer@solapur.gov.in', 'chief_engineer',         NULL),
  ('assistantengineer@solapur.gov.in','assistant_engineer', 'Central'),
  ('deputyengineer@solapur.gov.in','deputy_engineer',       'Central'),
  ('jrengineer@solapur.gov.in',   'junior_engineer',        'Central'),
  ('workgang@solapur.gov.in',     'work_gang',              'Central'),
  ('contractor@company.com',      'contractor',             'Central'),
  ('nagarsevak@solapur.gov.in',   'nagarsevak',             'Central'),
  ('citizen@gmail.com',           'citizen',                NULL),
  
  ('je.north@smcsolapur.gov.in',  'junior_engineer',        'North'),
  ('je.south@smcsolapur.gov.in',  'junior_engineer',        'South'),
  ('je.east@smcsolapur.gov.in',   'junior_engineer',        'East'),
  ('je.west@smcsolapur.gov.in',   'junior_engineer',        'West'),
  ('je.central@smcsolapur.gov.in','junior_engineer',        'Central'),
  ('je.cantt@smcsolapur.gov.in',  'junior_engineer',        'Cantonment'),
  ('ae@smcsolapur.gov.in',        'assistant_engineer',      NULL),
  ('de@smcsolapur.gov.in',        'deputy_engineer',         NULL),
  ('ce@smcsolapur.gov.in',        'chief_engineer',          NULL),
  ('comm@smcsolapur.gov.in',      'commissioner',            NULL),
  ('contractor1@smcsolapur.gov.in','contractor',             'North'),
  ('contractor2@smcsolapur.gov.in','contractor',             'South'),
  ('workgang1@smcsolapur.gov.in', 'work_gang',              'Central'),
  ('nagarsevak1@smcsolapur.gov.in','nagarsevak',             'East')
ON CONFLICT (email) DO NOTHING;

-- ──────────────────────────────────────
-- 2. Seed 50 complaints
-- ──────────────────────────────────────
INSERT INTO complaints (
  id, title, description, damage_type, severity, status,
  priority_score, epdo_score,
  lat, lng, location, ward,
  assigned_to, assigned_party_type, work_gang, official_remarks,
  images, current_handler, reported_by, upvotes,
  submitted_date, verified_date, last_update,
  received_at_current_level, total_potholes
) VALUES
-- ═══ Ward: North (8 complaints) ═══
('c001', 'Deep pothole on Akkalkot Road', 'Large pothole near MSRTC bus stand causing traffic jam', 'Pothole', 'Critical', 'In Progress',
 8.5, 8.2, 17.6945, 75.9120, 'Akkalkot Road, near MSRTC Bus Stand', 'North',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang A', 'Assigned to contractor, work started',
 ARRAY['https://placehold.co/400x300?text=Pothole+c001'], 'JE', 'citizen', 24,
 now() - interval '12 days', now() - interval '10 days', now() - interval '1 day',
 now() - interval '10 days', 3),

('c002', 'Cracked surface near Solapur University', 'Multiple cracks along approach road to university', 'Crack', 'High', 'Verified',
 7.1, 6.8, 17.7120, 75.9230, 'University Road, near Solapur University', 'North',
 NULL, NULL, NULL, 'Verified by JE, pending assignment',
 ARRAY['https://placehold.co/400x300?text=Crack+c002'], 'JE', 'citizen', 15,
 now() - interval '8 days', now() - interval '6 days', now() - interval '2 days',
 now() - interval '6 days', 0),

('c003', 'Water-logged depression on Hotgi Road', 'Depression collects rainwater, creates hazard for two-wheelers', 'Depression', 'High', 'Assigned',
 6.9, 7.3, 17.7055, 75.8985, 'Hotgi Road, near Railway Crossing', 'North',
 'contractor1@smcsolapur.gov.in', 'Contractor', NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Depression+c003'], 'JE', 'citizen', 11,
 now() - interval '15 days', now() - interval '13 days', now() - interval '5 days',
 now() - interval '13 days', 1),

('c004', 'Edge erosion on NH-65', 'Road edge crumbling near Solapur toll plaza', 'Edge Break', 'Critical', 'In Progress',
 9.0, 9.1, 17.7200, 75.8870, 'NH-65 near Solapur Toll Plaza', 'North',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang B', 'Priority repair underway',
 ARRAY['https://placehold.co/400x300?text=Edge+c004'], 'AE', 'citizen', 32,
 now() - interval '20 days', now() - interval '18 days', now() - interval '3 days',
 now() - interval '7 days', 5),

('c005', 'Pothole cluster near Vijapur Road bus stop', 'Three potholes in 20m stretch', 'Pothole', 'Medium', 'New',
 5.2, 4.8, 17.6990, 75.9310, 'Vijapur Road, near Ambedkar Chowk', 'North',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Pothole+c005'], 'JE', 'citizen', 6,
 now() - interval '3 days', NULL, now() - interval '3 days',
 now() - interval '3 days', 3),

('c006', 'Broken manhole cover on Murarji Peth', 'Manhole cover missing, dangerous at night', 'Manhole', 'Critical', 'Verified',
 8.8, 8.5, 17.6920, 75.9050, 'Murarji Peth, Ward 12', 'North',
 NULL, NULL, NULL, 'Extremely dangerous, prioritize',
 ARRAY['https://placehold.co/400x300?text=Manhole+c006'], 'JE', 'citizen', 28,
 now() - interval '5 days', now() - interval '4 days', now() - interval '1 day',
 now() - interval '4 days', 0),

('c007', 'Speed breaker damaged at Akluj Road', 'Speed breaker has broken edges', 'Surface Damage', 'Low', 'Resolved',
 3.2, 2.9, 17.7080, 75.8920, 'Akluj Road, near Petrol Pump', 'North',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang A', 'Repaired on-site',
 ARRAY['https://placehold.co/400x300?text=SpeedBreaker+c007'], 'JE', 'citizen', 4,
 now() - interval '30 days', now() - interval '28 days', now() - interval '10 days',
 now() - interval '28 days', 0),

('c008', 'Road cave-in near Ekrukh Road', 'Partial cave-in due to drainage pipe burst', 'Cave-in', 'Critical', 'In Progress',
 9.5, 9.3, 17.7150, 75.9150, 'Ekrukh Road, near Water Tank', 'North',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang C', 'Emergency repair',
 ARRAY['https://placehold.co/400x300?text=CaveIn+c008'], 'AE', 'citizen', 41,
 now() - interval '2 days', now() - interval '2 days', now() - interval '1 day',
 now() - interval '2 days', 2),

-- ═══ Ward: South (9 complaints) ═══
('c009', 'Pothole on Pune-Solapur Highway', 'Large pothole on main highway causing accidents', 'Pothole', 'Critical', 'In Progress',
 9.2, 9.0, 17.6650, 75.8950, 'Pune-Solapur Highway, Km 298', 'South',
 'contractor2@smcsolapur.gov.in', 'Contractor', 'Gang D', 'Urgent repair',
 ARRAY['https://placehold.co/400x300?text=Pothole+c009'], 'JE', 'citizen', 35,
 now() - interval '7 days', now() - interval '5 days', now() - interval '1 day',
 now() - interval '5 days', 4),

('c010', 'Cracked pavement at Siddheshwar Temple Road', 'Pavement cracked along pilgrim route', 'Crack', 'Medium', 'New',
 4.8, 5.2, 17.6780, 75.9000, 'Siddheshwar Temple Approach Road', 'South',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Crack+c010'], 'JE', 'citizen', 8,
 now() - interval '4 days', NULL, now() - interval '4 days',
 now() - interval '4 days', 0),

('c011', 'Waterlogged road near Kurduwadi junction', 'Chronic waterlogging during monsoon', 'Waterlogging', 'High', 'Assigned',
 7.0, 7.5, 17.6580, 75.9100, 'Kurduwadi Junction Road', 'South',
 'contractor2@smcsolapur.gov.in', 'Contractor', NULL, 'Drainage issue compounds damage',
 ARRAY['https://placehold.co/400x300?text=Waterlog+c011'], 'JE', 'citizen', 18,
 now() - interval '25 days', now() - interval '22 days', now() - interval '4 days',
 now() - interval '22 days', 2),

('c012', 'Surface peeling on Jule Solapur Road', 'Top layer peeling off in patches', 'Surface Damage', 'Medium', 'Verified',
 5.5, 5.0, 17.6710, 75.9180, 'Jule Solapur Main Road', 'South',
 NULL, NULL, NULL, 'Verified, needs re-surfacing',
 ARRAY['https://placehold.co/400x300?text=Peeling+c012'], 'JE', 'citizen', 9,
 now() - interval '10 days', now() - interval '8 days', now() - interval '3 days',
 now() - interval '8 days', 0),

('c013', 'Sinkhole forming near Solapur Fort', 'Small sinkhole appearing near historic fort', 'Sinkhole', 'Critical', 'In Progress',
 8.7, 8.9, 17.6700, 75.9060, 'Near Solapur Fort, Bhavani Peth', 'South',
 'contractor2@smcsolapur.gov.in', 'Contractor', 'Gang E', 'Heritage zone, careful repair needed',
 ARRAY['https://placehold.co/400x300?text=Sinkhole+c013'], 'DE', 'citizen', 22,
 now() - interval '18 days', now() - interval '16 days', now() - interval '2 days',
 now() - interval '5 days', 1),

('c014', 'Multiple potholes near Akkalkot bus route', 'Series of potholes on bus route', 'Pothole', 'High', 'Verified',
 7.4, 7.0, 17.6620, 75.8870, 'Akkalkot Bus Route, South Ward', 'South',
 NULL, NULL, NULL, 'Verified, 5 potholes identified',
 ARRAY['https://placehold.co/400x300?text=Potholes+c014'], 'JE', 'citizen', 14,
 now() - interval '6 days', now() - interval '5 days', now() - interval '2 days',
 now() - interval '5 days', 5),

('c015', 'Road shoulder damage on Barshi Road', 'Shoulder eroded, dangerous for pedestrians', 'Edge Break', 'Medium', 'New',
 5.0, 4.5, 17.6550, 75.9200, 'Barshi Road, KM 5', 'South',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Shoulder+c015'], 'JE', 'citizen', 3,
 now() - interval '2 days', NULL, now() - interval '2 days',
 now() - interval '2 days', 0),

('c016', 'Damaged drainage grate on Market Road', 'Drainage grate broken, water overflows onto road', 'Drainage', 'High', 'Assigned',
 6.8, 7.1, 17.6690, 75.9130, 'Market Road, old city', 'South',
 'contractor2@smcsolapur.gov.in', 'Contractor', NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Drainage+c016'], 'JE', 'citizen', 10,
 now() - interval '9 days', now() - interval '7 days', now() - interval '3 days',
 now() - interval '7 days', 0),

('c017', 'Repaired road re-damaged by rain', 'Patch repair washed out after first rain', 'Pothole', 'High', 'New',
 7.2, 6.5, 17.6600, 75.9050, 'Laxmi Peth, South Ward', 'South',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Redamage+c017'], 'JE', 'citizen', 16,
 now() - interval '1 day', NULL, now() - interval '1 day',
 now() - interval '1 day', 2),

-- ═══ Ward: East (8 complaints) ═══
('c018', 'Pothole near Solapur Railway Station', 'Large pothole at station approach road', 'Pothole', 'Critical', 'In Progress',
 8.9, 8.7, 17.6868, 75.9200, 'Railway Station Road, East', 'East',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang F', 'High priority — station area',
 ARRAY['https://placehold.co/400x300?text=Pothole+c018'], 'JE', 'citizen', 30,
 now() - interval '14 days', now() - interval '12 days', now() - interval '2 days',
 now() - interval '12 days', 4),

('c019', 'Uneven road at Sadar Bazaar', 'Road surface uneven from patch work', 'Surface Damage', 'Medium', 'Verified',
 5.3, 4.9, 17.6890, 75.9250, 'Sadar Bazaar Road', 'East',
 NULL, NULL, NULL, 'Multiple patch levels visible',
 ARRAY['https://placehold.co/400x300?text=Uneven+c019'], 'JE', 'citizen', 7,
 now() - interval '11 days', now() - interval '9 days', now() - interval '3 days',
 now() - interval '9 days', 0),

('c020', 'Deep cracks on Ashok Chowk Road', 'Long longitudinal cracks', 'Crack', 'High', 'Assigned',
 6.5, 6.8, 17.6830, 75.9290, 'Ashok Chowk, East Ward', 'East',
 'contractor1@smcsolapur.gov.in', 'Contractor', NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Cracks+c020'], 'JE', 'citizen', 12,
 now() - interval '16 days', now() - interval '14 days', now() - interval '5 days',
 now() - interval '14 days', 0),

('c021', 'Road surface uplift at Kegaon', 'Tree roots causing road uplift', 'Surface Damage', 'Medium', 'New',
 4.5, 4.2, 17.6950, 75.9350, 'Kegaon Main Road', 'East',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Uplift+c021'], 'JE', 'citizen', 5,
 now() - interval '5 days', NULL, now() - interval '5 days',
 now() - interval '5 days', 0),

('c022', 'Pothole cluster at Degaon Cross', 'Five potholes near busy intersection', 'Pothole', 'Critical', 'Verified',
 8.3, 8.0, 17.6810, 75.9180, 'Degaon Cross Junction', 'East',
 NULL, NULL, NULL, 'Critical intersection, needs urgent fix',
 ARRAY['https://placehold.co/400x300?text=Cluster+c022'], 'JE', 'citizen', 20,
 now() - interval '4 days', now() - interval '3 days', now() - interval '1 day',
 now() - interval '3 days', 5),

('c023', 'Damaged footpath on MG Road', 'Footpath tiles broken and displaced', 'Surface Damage', 'Low', 'Resolved',
 3.0, 2.5, 17.6860, 75.9270, 'MG Road, East Ward', 'East',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang A', 'Tiles replaced',
 ARRAY['https://placehold.co/400x300?text=Footpath+c023'], 'JE', 'citizen', 2,
 now() - interval '45 days', now() - interval '40 days', now() - interval '15 days',
 now() - interval '40 days', 0),

('c024', 'Collapsed drain at Budhwar Peth', 'Road collapsed around drain pipe', 'Cave-in', 'Critical', 'In Progress',
 9.1, 9.4, 17.6900, 75.9150, 'Budhwar Peth, near SBI Bank', 'East',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang G', 'Emergency repair underway',
 ARRAY['https://placehold.co/400x300?text=Collapse+c024'], 'AE', 'citizen', 33,
 now() - interval '3 days', now() - interval '3 days', now() - interval '1 day',
 now() - interval '3 days', 2),

('c025', 'Potholes on Mill Corner street', 'Small potholes appearing after pipe-laying work', 'Pothole', 'Medium', 'New',
 5.8, 5.5, 17.6840, 75.9310, 'Mill Corner, East Ward', 'East',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Pothole+c025'], 'JE', 'citizen', 4,
 now() - interval '1 day', NULL, now() - interval '1 day',
 now() - interval '1 day', 2),

-- ═══ Ward: West (9 complaints) ═══
('c026', 'Large pothole on Tuljapur Road', 'Deep pothole filled with muddy water', 'Pothole', 'Critical', 'In Progress',
 8.6, 8.3, 17.6868, 75.8850, 'Tuljapur Road, West Ward', 'West',
 'contractor2@smcsolapur.gov.in', 'Contractor', 'Gang H', 'Repair in progress',
 ARRAY['https://placehold.co/400x300?text=Pothole+c026'], 'JE', 'citizen', 19,
 now() - interval '13 days', now() - interval '11 days', now() - interval '2 days',
 now() - interval '11 days', 3),

('c027', 'Road subsidence at Gulbarga Road', 'Road sinking near construction site', 'Subsidence', 'High', 'Assigned',
 7.5, 7.8, 17.6800, 75.8780, 'Gulbarga Road, near new flyover', 'West',
 'contractor2@smcsolapur.gov.in', 'Contractor', NULL, 'Construction-related damage',
 ARRAY['https://placehold.co/400x300?text=Subsidence+c027'], 'JE', 'citizen', 13,
 now() - interval '19 days', now() - interval '17 days', now() - interval '4 days',
 now() - interval '17 days', 0),

('c028', 'Cracked divider on Mangalvedha Road', 'Road divider cracked and tilting', 'Surface Damage', 'Medium', 'Verified',
 5.0, 4.7, 17.6750, 75.8900, 'Mangalvedha Road, West Ward', 'West',
 NULL, NULL, NULL, 'Divider hazardous to bikers',
 ARRAY['https://placehold.co/400x300?text=Divider+c028'], 'JE', 'citizen', 7,
 now() - interval '8 days', now() - interval '6 days', now() - interval '2 days',
 now() - interval '6 days', 0),

('c029', 'Pothole near Saat Rasta', 'Pothole at major 7-road intersection', 'Pothole', 'Critical', 'In Progress',
 9.3, 9.0, 17.6900, 75.8930, 'Saat Rasta Junction', 'West',
 'contractor2@smcsolapur.gov.in', 'Contractor', 'Gang I', 'Maximum priority',
 ARRAY['https://placehold.co/400x300?text=Pothole+c029'], 'DE', 'citizen', 38,
 now() - interval '22 days', now() - interval '20 days', now() - interval '1 day',
 now() - interval '5 days', 6),

('c030', 'Gravel road deterioration at Bale', 'Gravel road completely washed out', 'Surface Damage', 'Medium', 'New',
 4.0, 3.8, 17.6700, 75.8750, 'Bale Village Road, West outskirts', 'West',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Gravel+c030'], 'JE', 'citizen', 2,
 now() - interval '6 days', NULL, now() - interval '6 days',
 now() - interval '6 days', 0),

('c031', 'Raised manhole on Latur Road', 'Manhole cover 3 inches above road surface', 'Manhole', 'High', 'Verified',
 7.8, 7.5, 17.6850, 75.8800, 'Latur Road, West Ward', 'West',
 NULL, NULL, NULL, 'Hazardous for vehicles at speed',
 ARRAY['https://placehold.co/400x300?text=Manhole+c031'], 'JE', 'citizen', 17,
 now() - interval '7 days', now() - interval '5 days', now() - interval '2 days',
 now() - interval '5 days', 0),

('c032', 'Potholes after pipeline work', 'Road not restored after water pipeline work', 'Pothole', 'High', 'Assigned',
 6.7, 7.2, 17.6920, 75.8860, 'Near Nehru Garden, West Ward', 'West',
 'contractor2@smcsolapur.gov.in', 'Contractor', NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Pipeline+c032'], 'JE', 'citizen', 11,
 now() - interval '12 days', now() - interval '10 days', now() - interval '3 days',
 now() - interval '10 days', 4),

('c033', 'Flooded road at Pandharpur junction', 'Chronic flooding at junction', 'Waterlogging', 'High', 'In Progress',
 7.0, 7.6, 17.6780, 75.8820, 'Pandharpur Road Junction', 'West',
 'contractor2@smcsolapur.gov.in', 'Contractor', 'Gang J', 'Drainage improvement ongoing',
 ARRAY['https://placehold.co/400x300?text=Flood+c033'], 'JE', 'citizen', 15,
 now() - interval '28 days', now() - interval '26 days', now() - interval '5 days',
 now() - interval '26 days', 0),

('c034', 'Road edge collapse on bypass', 'Edge of bypass road collapsing into field', 'Edge Break', 'Medium', 'Resolved',
 4.2, 3.9, 17.6650, 75.8880, 'Solapur Bypass Road, West', 'West',
 'contractor2@smcsolapur.gov.in', 'Contractor', 'Gang H', 'Edge reconstructed with retaining wall',
 ARRAY['https://placehold.co/400x300?text=Edge+c034'], 'JE', 'citizen', 5,
 now() - interval '35 days', now() - interval '33 days', now() - interval '12 days',
 now() - interval '33 days', 0),

-- ═══ Ward: Central (8 complaints) ═══
('c035', 'Pothole at Shivaji Chowk', 'Deep pothole at main city square', 'Pothole', 'Critical', 'In Progress',
 9.0, 8.8, 17.6868, 75.9074, 'Shivaji Chowk, Central Solapur', 'Central',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang K', 'City center repair priority',
 ARRAY['https://placehold.co/400x300?text=Pothole+c035'], 'JE', 'citizen', 40,
 now() - interval '5 days', now() - interval '4 days', now() - interval '1 day',
 now() - interval '4 days', 3),

('c036', 'Crumbling road near GPO', 'Road surface crumbling around General Post Office', 'Surface Damage', 'High', 'Verified',
 6.8, 6.5, 17.6880, 75.9100, 'GPO Road, Central Ward', 'Central',
 NULL, NULL, NULL, 'Heritage area, special materials needed',
 ARRAY['https://placehold.co/400x300?text=Crumble+c036'], 'JE', 'citizen', 12,
 now() - interval '9 days', now() - interval '7 days', now() - interval '3 days',
 now() - interval '7 days', 0),

('c037', 'Road damaged by heavy vehicle', 'Cement truck damaged residential road', 'Surface Damage', 'Medium', 'New',
 5.4, 5.0, 17.6840, 75.9050, 'Mangal Park Area, Central', 'Central',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=HeavyVehicle+c037'], 'JE', 'citizen', 6,
 now() - interval '3 days', NULL, now() - interval '3 days',
 now() - interval '3 days', 1),

('c038', 'Potholes near District Hospital', 'Multiple potholes on hospital approach', 'Pothole', 'Critical', 'Assigned',
 9.4, 9.6, 17.6900, 75.9080, 'District Hospital Road', 'Central',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang K', 'Hospital area — top priority',
 ARRAY['https://placehold.co/400x300?text=Hospital+c038'], 'AE', 'citizen', 45,
 now() - interval '4 days', now() - interval '3 days', now() - interval '1 day',
 now() - interval '3 days', 7),

('c039', 'Loose gravel on Tilak Road', 'Loose gravel causing skidding', 'Surface Damage', 'Medium', 'Verified',
 5.1, 4.6, 17.6850, 75.9040, 'Tilak Road, Central Solapur', 'Central',
 NULL, NULL, NULL, 'Gravel needs clearing and patching',
 ARRAY['https://placehold.co/400x300?text=Gravel+c039'], 'JE', 'citizen', 8,
 now() - interval '7 days', now() - interval '5 days', now() - interval '2 days',
 now() - interval '5 days', 0),

('c040', 'Collapsed culvert on inner ring road', 'Culvert collapsed causing road dip', 'Cave-in', 'Critical', 'In Progress',
 9.2, 9.5, 17.6870, 75.9020, 'Inner Ring Road, Central', 'Central',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang L', 'Structural repair needed',
 ARRAY['https://placehold.co/400x300?text=Culvert+c040'], 'CE', 'citizen', 37,
 now() - interval '25 days', now() - interval '23 days', now() - interval '2 days',
 now() - interval '3 days', 1),

('c041', 'Uneven speed breaker at Dufferin Chowk', 'Speed breaker too high, scraping vehicles', 'Surface Damage', 'Low', 'Resolved',
 2.8, 2.5, 17.6855, 75.9090, 'Dufferin Chowk, Central', 'Central',
 'workgang1@smcsolapur.gov.in', 'Work Gang', 'Gang M', 'Reshaped to standard height',
 ARRAY['https://placehold.co/400x300?text=SpeedBreaker+c041'], 'JE', 'citizen', 3,
 now() - interval '40 days', now() - interval '38 days', now() - interval '20 days',
 now() - interval '38 days', 0),

('c042', 'Road marking faded on Main Street', 'Lane markings completely faded', 'Surface Damage', 'Low', 'New',
 2.5, 2.0, 17.6875, 75.9060, 'Main Street, Central Solapur', 'Central',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Marking+c042'], 'JE', 'citizen', 1,
 now() - interval '2 days', NULL, now() - interval '2 days',
 now() - interval '2 days', 0),

-- ═══ Ward: Cantonment (8 complaints) ═══
('c043', 'Pothole on Cantonment Road', 'Deep pothole near military area entrance', 'Pothole', 'High', 'Verified',
 7.6, 7.3, 17.6750, 75.9250, 'Cantonment Main Road', 'Cantonment',
 NULL, NULL, NULL, 'Verified, coordination with military needed',
 ARRAY['https://placehold.co/400x300?text=Pothole+c043'], 'JE', 'citizen', 14,
 now() - interval '10 days', now() - interval '8 days', now() - interval '3 days',
 now() - interval '8 days', 2),

('c044', 'Road crack near Solapur Airport', 'Long transverse crack on airport road', 'Crack', 'Medium', 'New',
 5.5, 5.8, 17.6600, 75.9330, 'Airport Road, Cantonment', 'Cantonment',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Crack+c044'], 'JE', 'citizen', 5,
 now() - interval '4 days', NULL, now() - interval '4 days',
 now() - interval '4 days', 0),

('c045', 'Waterlogging at Sadar Bazaar extension', 'Chronic waterlogging after every rain', 'Waterlogging', 'High', 'In Progress',
 7.3, 7.7, 17.6720, 75.9300, 'Sadar Bazaar Extension, Cantonment', 'Cantonment',
 'contractor1@smcsolapur.gov.in', 'Contractor', NULL, 'Drainage improvement planned',
 ARRAY['https://placehold.co/400x300?text=Waterlog+c045'], 'JE', 'citizen', 16,
 now() - interval '21 days', now() - interval '19 days', now() - interval '4 days',
 now() - interval '19 days', 0),

('c046', 'Broken road near MIDC area', 'Industrial traffic destroyed local road', 'Surface Damage', 'Critical', 'Assigned',
 8.0, 8.4, 17.6680, 75.9380, 'MIDC Phase II Road, Cantonment', 'Cantonment',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang N', NULL,
 ARRAY['https://placehold.co/400x300?text=MIDC+c046'], 'AE', 'citizen', 21,
 now() - interval '17 days', now() - interval '15 days', now() - interval '3 days',
 now() - interval '6 days', 3),

('c047', 'Pothole on Camp area road', 'Pothole in commercial zone, heavy foot traffic', 'Pothole', 'High', 'Verified',
 7.0, 6.7, 17.6770, 75.9270, 'Camp Area, Main Bazaar Road', 'Cantonment',
 NULL, NULL, NULL, 'Commercial zone, repair during night',
 ARRAY['https://placehold.co/400x300?text=Pothole+c047'], 'JE', 'citizen', 11,
 now() - interval '6 days', now() - interval '4 days', now() - interval '2 days',
 now() - interval '4 days', 2),

('c048', 'Road surface buckling at Borsline', 'Asphalt buckling in hot weather', 'Surface Damage', 'Medium', 'New',
 4.8, 4.3, 17.6640, 75.9220, 'Borsline Area, Cantonment', 'Cantonment',
 NULL, NULL, NULL, NULL,
 ARRAY['https://placehold.co/400x300?text=Buckle+c048'], 'JE', 'citizen', 3,
 now() - interval '3 days', NULL, now() - interval '3 days',
 now() - interval '3 days', 0),

('c049', 'Massive pothole on Yeshwant Nagar approach', 'Very deep pothole causing two-wheeler accidents', 'Pothole', 'Critical', 'In Progress',
 9.1, 8.8, 17.6730, 75.9190, 'Yeshwant Nagar Approach Road', 'Cantonment',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang O', 'Multiple accident reports',
 ARRAY['https://placehold.co/400x300?text=Pothole+c049'], 'JE', 'citizen', 29,
 now() - interval '8 days', now() - interval '6 days', now() - interval '1 day',
 now() - interval '6 days', 4),

('c050', 'Damaged road near Cantonment railway halt', 'Road damaged from heavy goods loading/unloading', 'Surface Damage', 'Medium', 'Resolved',
 4.5, 4.0, 17.6760, 75.9350, 'Cantonment Railway Halt Road', 'Cantonment',
 'contractor1@smcsolapur.gov.in', 'Contractor', 'Gang N', 'Repaired with hotmix',
 ARRAY['https://placehold.co/400x300?text=Damage+c050'], 'JE', 'citizen', 6,
 now() - interval '50 days', now() - interval '48 days', now() - interval '18 days',
 now() - interval '48 days', 0)

ON CONFLICT (id) DO NOTHING;
