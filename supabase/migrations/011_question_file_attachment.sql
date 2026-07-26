-- Migration 011: Question File Attachment
-- Adds professor question-file metadata to assignments and tightens storage RLS.

-- ── 1. Schema additions ────────────────────────────────────────────────────────

alter table assignments
  add column if not exists question_file_path text,   -- storage path: questions/{id}/{filename}
  add column if not exists question_file_name text;   -- original display name shown to students

-- ── 2. Storage RLS – drop the broad policies from migration 010 ───────────────
-- The original policies allowed any authenticated user to read/write the entire
-- bucket. We replace them with path-scoped policies.

drop policy if exists "student_upload"       on storage.objects;
drop policy if exists "authenticated_read"   on storage.objects;

-- ── 3. Faculty: write only to questions/{assignment_id}/ ──────────────────────
-- The assignment must belong to the uploading faculty member (checked via a
-- sub-select). Path format: questions/<uuid>/<filename>

create policy "faculty_upload_question" on storage.objects
  for insert
  with check (
    bucket_id = 'assignments'
    and auth.role() = 'authenticated'
    -- path segment [0] = 'questions', segment [1] = assignment_id
    and (storage.foldername(name))[1] = 'questions'
    and exists (
      select 1 from assignments a
      where a.id::text = (storage.foldername(name))[2]
        and a.faculty_id = auth.uid()
    )
  );

-- Faculty can overwrite their question file (upsert = DELETE + INSERT in storage)
create policy "faculty_update_question" on storage.objects
  for update
  using (
    bucket_id = 'assignments'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = 'questions'
    and exists (
      select 1 from assignments a
      where a.id::text = (storage.foldername(name))[2]
        and a.faculty_id = auth.uid()
    )
  );

-- ── 4. Students: write only to submissions/{assignment_id}/{student_id}/ ───────

create policy "student_upload_submission" on storage.objects
  for insert
  with check (
    bucket_id = 'assignments'
    and auth.role() = 'authenticated'
    -- path segment [0] = 'submissions', segment [2] = student_id
    and (storage.foldername(name))[1] = 'submissions'
    and (storage.foldername(name))[3] = auth.uid()::text
    -- student must be actively enrolled in the assignment's course
    and exists (
      select 1 from assignments a
      join student_enrollments se on se.course_id = a.course_id
      where a.id::text      = (storage.foldername(name))[2]
        and se.student_id   = auth.uid()
        and se.status       = 'active'
    )
  );

-- Students can overwrite their own submission (resubmit)
create policy "student_update_submission" on storage.objects
  for update
  using (
    bucket_id = 'assignments'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = 'submissions'
    and (storage.foldername(name))[3] = auth.uid()::text
  );

-- ── 5. Read: any authenticated user may read (signed URLs gate real access) ───
-- Signed URLs are generated server-side and expire in 1 hour, so granting broad
-- SELECT here does not expose files — unauthenticated callers still cannot get a
-- signed URL.

create policy "authenticated_read_assignments_bucket" on storage.objects
  for select
  using (
    bucket_id = 'assignments'
    and auth.role() = 'authenticated'
  );
