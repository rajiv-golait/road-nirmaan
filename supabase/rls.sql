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
