-- Migration 007: Add ON DELETE CASCADE to foreign keys referencing profiles
-- Problem: Deleting a profile fails with FK violation because student_enrollments
--          and attendance_records still reference the user's id.
-- Fix: Recreate those FK constraints with ON DELETE CASCADE so all related
--      rows are automatically cleaned up when a profile is deleted.
-- Run: supabase db push

-- ── student_enrollments.student_id ───────────────────────────────────────────
ALTER TABLE student_enrollments
  DROP CONSTRAINT IF EXISTS enrollments_student_id_fkey;

ALTER TABLE student_enrollments
  DROP CONSTRAINT IF EXISTS student_enrollments_student_id_fkey;

ALTER TABLE student_enrollments
  ADD CONSTRAINT student_enrollments_student_id_fkey
  FOREIGN KEY (student_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

-- ── attendance_records.student_id ────────────────────────────────────────────
ALTER TABLE attendance_records
  DROP CONSTRAINT IF EXISTS attendance_records_student_id_fkey;

ALTER TABLE attendance_records
  ADD CONSTRAINT attendance_records_student_id_fkey
  FOREIGN KEY (student_id)
  REFERENCES profiles(id)
  ON DELETE CASCADE;

-- ── attendance_sessions.faculty_id ───────────────────────────────────────────
-- Also fix faculty sessions so deleting a faculty profile doesn't break either
ALTER TABLE attendance_sessions
  DROP CONSTRAINT IF EXISTS attendance_sessions_faculty_id_fkey;

ALTER TABLE attendance_sessions
  ADD CONSTRAINT attendance_sessions_faculty_id_fkey
  FOREIGN KEY (faculty_id)
  REFERENCES profiles(id)
  ON DELETE SET NULL;

-- ── attendance_audit_logs.admin_id ───────────────────────────────────────────
ALTER TABLE attendance_audit_logs
  DROP CONSTRAINT IF EXISTS attendance_audit_logs_admin_id_fkey;

ALTER TABLE attendance_audit_logs
  ADD CONSTRAINT attendance_audit_logs_admin_id_fkey
  FOREIGN KEY (admin_id)
  REFERENCES profiles(id)
  ON DELETE SET NULL;
