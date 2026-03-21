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
