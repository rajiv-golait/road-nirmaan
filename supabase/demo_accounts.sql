-- ============================================================
-- Demo accounts for hackathon (run AFTER creating users in
-- Supabase Auth with the same emails and password Demo@Road2024)
-- ============================================================
-- Auth users to create manually in Supabase Dashboard → Authentication:
--   citizen@demo.roadnirman.in
--   je.zone1@demo.roadnirman.in
--   contractor@demo.roadnirman.in
--   commissioner@demo.roadnirman.in
--   ac@demo.roadnirman.in
--   ce@demo.roadnirman.in
--   de.zone1@demo.roadnirman.in
--   ae.zone1@demo.roadnirman.in
--   workgang.zone1@demo.roadnirman.in
--   nagarsevak.zone1@demo.roadnirman.in
-- Password for each: Demo@Road2024
--
-- Requires user_roles.user_id (see schema.sql / migrate.sql).

INSERT INTO user_roles (email, role, ward_zone, user_id)
SELECT v.email, v.role, v.ward_zone, au.id
FROM (
  VALUES
    ('citizen@demo.roadnirman.in', 'citizen', NULL::text),
    ('je.zone1@demo.roadnirman.in', 'junior_engineer', 'Zone 1'),
    ('contractor@demo.roadnirman.in', 'contractor', 'Zone 1'),
    ('commissioner@demo.roadnirman.in', 'commissioner', NULL::text),

    -- Remaining dashboards
    ('ac@demo.roadnirman.in', 'assistant_commissioner', NULL::text),
    ('ce@demo.roadnirman.in', 'chief_engineer', NULL::text),
    ('de.zone1@demo.roadnirman.in', 'deputy_engineer', 'Zone 1'),
    ('ae.zone1@demo.roadnirman.in', 'assistant_engineer', 'Zone 1'),
    ('workgang.zone1@demo.roadnirman.in', 'work_gang', 'Zone 1'),
    ('nagarsevak.zone1@demo.roadnirman.in', 'nagarsevak', 'Zone 1')
) AS v(email, role, ward_zone)
JOIN auth.users au ON LOWER(TRIM(au.email)) = LOWER(TRIM(v.email))
ON CONFLICT (email) DO UPDATE SET
  role = EXCLUDED.role,
  ward_zone = EXCLUDED.ward_zone,
  user_id = EXCLUDED.user_id;
