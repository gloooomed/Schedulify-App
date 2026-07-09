-- ============================================================
-- Migration 010: Enrolment Triggers Fix + Full Production Schema
-- Run AFTER: schema.sql, migration_v2.sql, migrations 003-009
--
-- This migration does two things:
--   A) Fixes 3 critical bugs in Migration 009
--   B) Adds all remaining production tables (Notifications,
--      Announcements, Assignments, Tests, Coding Tests)
--
-- Safe to re-run — all DDL uses IF NOT EXISTS / OR REPLACE guards
-- ============================================================


-- ============================================================
-- PART A — FIX MIGRATION 009 BUGS
-- ============================================================

-- ── BUG 1 (CRITICAL): Missing UNIQUE constraint on student_enrollments ────────
-- ON CONFLICT (student_id, course_id) in Migration 009 requires this.
-- Without it, every ON CONFLICT clause silently throws a runtime error.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'student_enrollments_student_id_course_id_key'
  ) THEN
    ALTER TABLE student_enrollments
      ADD CONSTRAINT student_enrollments_student_id_course_id_key
      UNIQUE (student_id, course_id);
  END IF;
END $$;


-- ── BUG 2 (CRITICAL): Trigger for auto_enroll_on_student_create was MISSING ──
-- The function was created in Migration 009 but the trigger was never attached.
DROP TRIGGER IF EXISTS trg_auto_enroll_on_student_create ON profiles;
CREATE TRIGGER trg_auto_enroll_on_student_create
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_enroll_on_student_create();


-- ── BUG 3 (CRITICAL): Trigger for auto_enroll_on_department_change was MISSING
-- The function was created in Migration 009 but the trigger was never attached.
-- Also fixed: added WHEN guard so it only fires when department_id actually
-- changes AND old value is not null (avoids deleting enrollments on first set).
DROP TRIGGER IF EXISTS trg_auto_enroll_on_department_change ON profiles;
CREATE TRIGGER trg_auto_enroll_on_department_change
  AFTER UPDATE OF department_id ON profiles
  FOR EACH ROW
  WHEN (
    NEW.role = 'student'
    AND NEW.department_id IS NOT NULL
    AND NEW.department_id IS DISTINCT FROM OLD.department_id
  )
  EXECUTE FUNCTION auto_enroll_on_department_change();


-- ── FIX: Safer auto_enroll_on_department_change — guard old NULL ──────────────
-- Re-create the function with an explicit guard so it never tries to DELETE
-- enrollments when OLD.department_id is NULL (i.e. first assignment of dept).
CREATE OR REPLACE FUNCTION auto_enroll_on_department_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only remove old-dept enrollments when there actually WAS an old department
  IF OLD.department_id IS NOT NULL THEN
    DELETE FROM student_enrollments se
    WHERE se.student_id = NEW.id
      AND EXISTS (
        SELECT 1 FROM courses c
        WHERE c.id = se.course_id
          AND c.department_id = OLD.department_id
      );
  END IF;

  -- Enroll in all new department courses
  INSERT INTO student_enrollments (student_id, course_id, status)
  SELECT NEW.id, c.id, 'active'
  FROM courses c
  WHERE c.department_id = NEW.department_id
  ON CONFLICT (student_id, course_id) DO NOTHING;

  RETURN NEW;
END;
$$;


-- ============================================================
-- PART B — PRODUCTION TABLES
-- ============================================================


-- ── 1. FCM Device Tokens ─────────────────────────────────────────────────────
-- Stores FCM push tokens per user per device. One user can have many devices.
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token      text        NOT NULL,
  platform   text        NOT NULL DEFAULT 'android'
             CHECK (platform IN ('android', 'ios', 'web')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_fcm_user ON fcm_tokens (user_id);


-- ── 2. Notifications ─────────────────────────────────────────────────────────
-- System-generated in-app + push notifications per user.
CREATE TABLE IF NOT EXISTS notifications (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title        text        NOT NULL,
  body         text        NOT NULL,
  type         text        NOT NULL DEFAULT 'system'
               CHECK (type IN (
                 'attendance',   -- session opened / low attendance warning
                 'assignment',   -- posted / deadline reminder / graded
                 'test',         -- scheduled / result published
                 'announcement', -- college / department / batch notice
                 'system'        -- general app notifications
               )),
  -- Optional deep-link payload. e.g. {"route": "/student/assignments/abc-123"}
  metadata     jsonb,
  is_read      bool        NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notif_recipient ON notifications (recipient_id, is_read, created_at DESC);


-- ── 3. Announcements ─────────────────────────────────────────────────────────
-- Admin/Faculty posts a notice targeted at a scope.
CREATE TABLE IF NOT EXISTS announcements (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  posted_by    uuid        NOT NULL REFERENCES profiles(id),
  title        text        NOT NULL,
  content      text        NOT NULL,
  target_scope text        NOT NULL DEFAULT 'college'
               CHECK (target_scope IN ('college', 'department', 'batch', 'individual')),
  -- Points to a department_id, batch string, or profile_id depending on scope
  target_id    text,
  is_pinned    bool        NOT NULL DEFAULT false,
  expires_at   timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_announce_scope ON announcements (target_scope, target_id, created_at DESC);


-- ── 4. Assignments ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS assignments (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id     uuid        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  faculty_id    uuid        NOT NULL REFERENCES profiles(id),
  department_id uuid        REFERENCES departments(id),
  title         text        NOT NULL,
  description   text,
  due_at        timestamptz NOT NULL,
  total_marks   int         NOT NULL DEFAULT 100,
  -- NULL means all file types allowed
  allowed_types text,       -- e.g. 'application/pdf,image/jpeg'
  max_file_mb   int         NOT NULL DEFAULT 10,
  status        text        NOT NULL DEFAULT 'published'
                CHECK (status IN ('draft', 'published', 'closed')),
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_assign_course  ON assignments (course_id, due_at);
CREATE INDEX IF NOT EXISTS idx_assign_faculty ON assignments (faculty_id);


-- ── 5. Assignment Submissions ────────────────────────────────────────────────
-- One row per student per assignment. Re-submission overwrites file_url.
CREATE TABLE IF NOT EXISTS assignment_submissions (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid        NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
  student_id    uuid        NOT NULL REFERENCES profiles(id),
  -- Supabase Storage path: assignments/{assignment_id}/{student_id}/filename
  file_url      text,
  file_name     text,
  submitted_at  timestamptz NOT NULL DEFAULT now(),
  -- Grading (filled by faculty after review)
  marks_obtained numeric,
  feedback      text,
  graded_at     timestamptz,
  graded_by     uuid        REFERENCES profiles(id),
  UNIQUE (assignment_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_sub_assignment ON assignment_submissions (assignment_id);
CREATE INDEX IF NOT EXISTS idx_sub_student    ON assignment_submissions (student_id);


-- ── 6. Tests ─────────────────────────────────────────────────────────────────
-- Parent record for both MCQ and coding tests.
CREATE TABLE IF NOT EXISTS tests (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id         uuid        REFERENCES courses(id),
  department_id     uuid        REFERENCES departments(id),
  created_by        uuid        NOT NULL REFERENCES profiles(id),
  title             text        NOT NULL,
  description       text,
  type              text        NOT NULL DEFAULT 'mcq'
                    CHECK (type IN ('mcq', 'coding')),
  start_at          timestamptz,
  end_at            timestamptz,
  duration_minutes  int         NOT NULL DEFAULT 60,
  total_marks       int         NOT NULL DEFAULT 100,
  passing_marks     int,
  negative_marking  numeric     NOT NULL DEFAULT 0,
  shuffle_questions bool        NOT NULL DEFAULT true,
  shuffle_options   bool        NOT NULL DEFAULT true,
  status            text        NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'scheduled', 'live', 'closed', 'archived')),
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tests_course  ON tests (course_id, status);
CREATE INDEX IF NOT EXISTS idx_tests_creator ON tests (created_by);


-- ── 7. MCQ Questions ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS test_questions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id     uuid        NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  question    text        NOT NULL,
  image_url   text,
  marks       int         NOT NULL DEFAULT 1,
  sort_order  int         NOT NULL DEFAULT 0,
  explanation text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tq_test ON test_questions (test_id, sort_order);


-- ── 8. MCQ Options ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS test_options (
  id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid    NOT NULL REFERENCES test_questions(id) ON DELETE CASCADE,
  option_text text    NOT NULL,
  image_url   text,
  is_correct  bool    NOT NULL DEFAULT false,
  sort_order  int     NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_to_question ON test_options (question_id);


-- ── 9. Test Submissions (MCQ) ────────────────────────────────────────────────
-- One row per student per test. Tracks start/end and final score.
CREATE TABLE IF NOT EXISTS test_submissions (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id         uuid        NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  student_id      uuid        NOT NULL REFERENCES profiles(id),
  started_at      timestamptz NOT NULL DEFAULT now(),
  submitted_at    timestamptz,
  score           numeric,
  total_attempted int         NOT NULL DEFAULT 0,
  is_auto_submit  bool        NOT NULL DEFAULT false,
  tab_switches    int         NOT NULL DEFAULT 0,
  UNIQUE (test_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_ts_test    ON test_submissions (test_id);
CREATE INDEX IF NOT EXISTS idx_ts_student ON test_submissions (student_id);


-- ── 10. Test Answers (MCQ) ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS test_answers (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id      uuid        NOT NULL REFERENCES test_submissions(id) ON DELETE CASCADE,
  question_id        uuid        NOT NULL REFERENCES test_questions(id),
  selected_option_id uuid        REFERENCES test_options(id),  -- NULL if skipped
  is_correct         bool,
  marks_awarded      numeric,
  answered_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (submission_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_ta_submission ON test_answers (submission_id);


-- ── 11. Coding Problems ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS coding_problems (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id           uuid        NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  title             text        NOT NULL,
  statement         text        NOT NULL,
  constraints       text,
  input_format      text,
  output_format     text,
  sample_input      text,
  sample_output     text,
  difficulty        text        NOT NULL DEFAULT 'medium'
                    CHECK (difficulty IN ('easy', 'medium', 'hard')),
  marks             int         NOT NULL DEFAULT 10,
  time_limit_ms     int         NOT NULL DEFAULT 2000,
  memory_limit_kb   int         NOT NULL DEFAULT 256000,
  allowed_languages jsonb       NOT NULL DEFAULT '["python","java","cpp","javascript"]',
  sort_order        int         NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cp_test ON coding_problems (test_id, sort_order);


-- ── 12. Coding Test Cases ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS coding_test_cases (
  id              uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  problem_id      uuid    NOT NULL REFERENCES coding_problems(id) ON DELETE CASCADE,
  input           text    NOT NULL,
  expected_output text    NOT NULL,
  is_hidden       bool    NOT NULL DEFAULT true,
  marks           int     NOT NULL DEFAULT 0,
  sort_order      int     NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_ctc_problem ON coding_test_cases (problem_id);


-- ── 13. Coding Submissions ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS coding_submissions (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  problem_id         uuid        NOT NULL REFERENCES coding_problems(id) ON DELETE CASCADE,
  student_id         uuid        NOT NULL REFERENCES profiles(id),
  test_id            uuid        REFERENCES tests(id),
  language           text        NOT NULL
                     CHECK (language IN ('python', 'java', 'cpp', 'javascript')),
  code               text        NOT NULL,
  verdict            text        NOT NULL DEFAULT 'pending'
                     CHECK (verdict IN (
                       'pending', 'running',
                       'accepted',
                       'wrong_answer',
                       'time_limit_exceeded',
                       'memory_limit_exceeded',
                       'runtime_error',
                       'compilation_error',
                       'internal_error'
                     )),
  judge0_token       text,
  runtime_ms         int,
  memory_kb          int,
  test_cases_passed  int         NOT NULL DEFAULT 0,
  test_cases_total   int         NOT NULL DEFAULT 0,
  marks_awarded      numeric,
  case_results       jsonb,
  submitted_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cs_problem ON coding_submissions (problem_id, student_id);
CREATE INDEX IF NOT EXISTS idx_cs_student ON coding_submissions (student_id);
CREATE INDEX IF NOT EXISTS idx_cs_verdict ON coding_submissions (verdict, submitted_at DESC);


-- ============================================================
-- RLS POLICIES (PART B)
-- ============================================================

DO $$ BEGIN

  -- fcm_tokens: user manages own tokens only
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='fcm_tokens' AND policyname='user_own_fcm') THEN
    ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "user_own_fcm" ON fcm_tokens FOR ALL
      USING (user_id = auth.uid());
  END IF;

  -- notifications: user reads own; admin/faculty creates
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='notifications' AND policyname='user_own_notif') THEN
    ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "user_own_notif" ON notifications FOR SELECT
      USING (recipient_id = auth.uid());
    CREATE POLICY "user_mark_read" ON notifications FOR UPDATE
      USING (recipient_id = auth.uid());
    CREATE POLICY "admin_create_notif" ON notifications FOR INSERT
      WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin', 'faculty'))
      );
  END IF;

  -- announcements: all authenticated can read; faculty/admin can write
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='announcements' AND policyname='auth_read_announce') THEN
    ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "auth_read_announce" ON announcements FOR SELECT
      USING (auth.role() = 'authenticated');
    CREATE POLICY "staff_manage_announce" ON announcements FOR ALL
      USING (
        posted_by = auth.uid() OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
      );
  END IF;

  -- assignments: enrolled students can read; faculty/admin manage
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='assignments' AND policyname='student_read_assign') THEN
    ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "student_read_assign" ON assignments FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM student_enrollments se
          WHERE se.student_id = auth.uid() AND se.course_id = assignments.course_id
        ) OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin'))
      );
    CREATE POLICY "faculty_manage_assign" ON assignments FOR ALL
      USING (
        faculty_id = auth.uid() OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
      );
  END IF;

  -- assignment_submissions: student sees own; faculty of that assignment sees all
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='assignment_submissions' AND policyname='student_own_sub') THEN
    ALTER TABLE assignment_submissions ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "student_own_sub" ON assignment_submissions FOR ALL
      USING (student_id = auth.uid());
    CREATE POLICY "faculty_view_subs" ON assignment_submissions FOR SELECT
      USING (
        EXISTS (
          SELECT 1 FROM assignments a
          WHERE a.id = assignment_submissions.assignment_id AND a.faculty_id = auth.uid()
        ) OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
      );
    CREATE POLICY "faculty_grade_subs" ON assignment_submissions FOR UPDATE
      USING (
        EXISTS (
          SELECT 1 FROM assignments a
          WHERE a.id = assignment_submissions.assignment_id AND a.faculty_id = auth.uid()
        ) OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
      );
  END IF;

  -- tests: authenticated read published/live/closed; staff manage
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='tests' AND policyname='auth_read_tests') THEN
    ALTER TABLE tests ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "auth_read_tests" ON tests FOR SELECT
      USING (
        (status IN ('scheduled', 'live', 'closed') AND auth.role() = 'authenticated') OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin'))
      );
    CREATE POLICY "staff_manage_tests" ON tests FOR ALL
      USING (
        created_by = auth.uid() OR
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
      );
  END IF;

  -- test_questions: authenticated read; staff manage
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='test_questions' AND policyname='auth_read_tq') THEN
    ALTER TABLE test_questions ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "auth_read_tq" ON test_questions FOR SELECT USING (auth.role() = 'authenticated');
    CREATE POLICY "staff_manage_tq" ON test_questions FOR ALL
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin')));
  END IF;

  -- test_options: authenticated read; staff manage
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='test_options' AND policyname='auth_read_to') THEN
    ALTER TABLE test_options ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "auth_read_to" ON test_options FOR SELECT USING (auth.role() = 'authenticated');
    CREATE POLICY "staff_manage_to" ON test_options FOR ALL
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin')));
  END IF;

  -- test_submissions: student sees own; staff sees all
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='test_submissions' AND policyname='student_own_test_sub') THEN
    ALTER TABLE test_submissions ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "student_own_test_sub" ON test_submissions FOR ALL
      USING (student_id = auth.uid());
    CREATE POLICY "staff_view_test_subs" ON test_submissions FOR SELECT
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin')));
  END IF;

  -- test_answers: student sees own (via submission); staff sees all
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='test_answers' AND policyname='student_own_ta') THEN
    ALTER TABLE test_answers ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "student_own_ta" ON test_answers FOR ALL
      USING (EXISTS (
        SELECT 1 FROM test_submissions ts
        WHERE ts.id = test_answers.submission_id AND ts.student_id = auth.uid()
      ));
    CREATE POLICY "staff_view_ta" ON test_answers FOR SELECT
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin')));
  END IF;

  -- coding_problems: authenticated read; staff manage
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='coding_problems' AND policyname='auth_read_cp') THEN
    ALTER TABLE coding_problems ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "auth_read_cp" ON coding_problems FOR SELECT USING (auth.role() = 'authenticated');
    CREATE POLICY "staff_manage_cp" ON coding_problems FOR ALL
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin')));
  END IF;

  -- coding_test_cases: students see non-hidden only; staff sees all
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='coding_test_cases' AND policyname='student_visible_tc') THEN
    ALTER TABLE coding_test_cases ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "student_visible_tc" ON coding_test_cases FOR SELECT
      USING (is_hidden = false AND auth.role() = 'authenticated');
    CREATE POLICY "staff_all_tc" ON coding_test_cases FOR ALL
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin')));
  END IF;

  -- coding_submissions: student sees own; staff sees all
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='coding_submissions' AND policyname='student_own_cs') THEN
    ALTER TABLE coding_submissions ENABLE ROW LEVEL SECURITY;
    CREATE POLICY "student_own_cs" ON coding_submissions FOR ALL
      USING (student_id = auth.uid());
    CREATE POLICY "staff_view_cs" ON coding_submissions FOR SELECT
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin', 'super_admin')));
  END IF;

END $$;


-- ============================================================
-- REALTIME
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE coding_submissions;


-- ============================================================
-- VERIFY — run this SELECT after migration to confirm all tables:
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
--
-- Expected 24 tables:
--   announcements, assignment_submissions, assignments,
--   attendance_audit_logs, attendance_records, attendance_sessions,
--   classrooms, coding_problems, coding_submissions, coding_test_cases,
--   courses, departments, fcm_tokens, geofence_config,
--   notifications, profiles, student_enrollments,
--   test_answers, test_options, test_questions, test_submissions, tests,
--   timetable_entries, timetables
-- ============================================================
