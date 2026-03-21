-- ============================================================
-- Demo accounts for hackathon (run AFTER creating users in
-- Supabase Auth with the same emails and password Demo@Road2024)
-- ============================================================
-- Auth users to create manually in Supabase Dashboard → Authentication:
--   citizen@demo.roadnirman.in
--   je.zone1@demo.roadnirman.in
--   contractor@demo.roadnirman.in
--   commissioner@demo.roadnirman.in
-- Password for each: Demo@Road2024

INSERT INTO user_roles (email, role, ward_zone) VALUES
  ('citizen@demo.roadnirman.in', 'citizen', NULL),
  ('je.zone1@demo.roadnirman.in', 'junior_engineer', 'Zone 1'),
  ('contractor@demo.roadnirman.in', 'contractor', NULL),
  ('commissioner@demo.roadnirman.in', 'commissioner', NULL)
ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  ward_zone = EXCLUDED.ward_zone;
