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
--
-- Requires user_roles.user_id (see schema.sql / migrate.sql).

INSERT INTO user_roles (email, role, ward_zone, user_id)
SELECT v.email, v.role, v.ward_zone, au.id
FROM (
  VALUES
    ('citizen@demo.roadnirman.in', 'citizen', NULL::text),
    ('je.zone1@demo.roadnirman.in', 'junior_engineer', 'Zone 1'),
    ('contractor@demo.roadnirman.in', 'contractor', NULL::text),
    ('commissioner@demo.roadnirman.in', 'commissioner', NULL::text)
) AS v(email, role, ward_zone)
JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(v.email))
ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  ward_zone = EXCLUDED.ward_zone,
  user_id = EXCLUDED.user_id;
