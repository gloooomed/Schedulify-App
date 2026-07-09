-- Migration 008: Auto-enroll new students when their profile is created
-- Problem: The existing trigger in migration 003 only fires when a timetable
--          is published. Students created AFTER the timetable was published
--          are never enrolled in any courses.
-- Fix: Add a trigger on profiles INSERT so that when a new student is added,
--      they are immediately enrolled in the currently published timetable
--      for their department.
-- Run: supabase db push

CREATE OR REPLACE FUNCTION auto_enroll_on_student_create()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only run for new student profiles that have a department assigned
  IF NEW.role = 'student' AND NEW.department_id IS NOT NULL THEN

    INSERT INTO student_enrollments (student_id, course_id, status)
    SELECT
      NEW.id       AS student_id,
      te.course_id AS course_id,
      'active'     AS status
    FROM timetables t
    JOIN timetable_entries te ON te.timetable_id = t.id
    JOIN courses c ON c.id = te.course_id
    WHERE t.status          = 'published'
      AND t.department_id   = NEW.department_id
      AND c.department_id   = NEW.department_id   -- enforce dept scoping
      AND te.course_id IS NOT NULL
    ON CONFLICT (student_id, course_id) DO NOTHING;

  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_enroll_on_student_create ON profiles;

CREATE TRIGGER trg_auto_enroll_on_student_create
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_enroll_on_student_create();

-- Also handle when a student's department_id is updated
-- (e.g., admin fixes a wrong department assignment)
CREATE OR REPLACE FUNCTION auto_enroll_on_department_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role = 'student'
     AND NEW.department_id IS NOT NULL
     AND NEW.department_id IS DISTINCT FROM OLD.department_id THEN

    -- Remove enrollments from the OLD department's courses
    DELETE FROM student_enrollments se
    WHERE se.student_id = NEW.id
      AND EXISTS (
        SELECT 1 FROM courses c
        WHERE c.id = se.course_id
          AND c.department_id = OLD.department_id
      );

    -- Enroll in the NEW department's published timetable
    INSERT INTO student_enrollments (student_id, course_id, status)
    SELECT
      NEW.id       AS student_id,
      te.course_id AS course_id,
      'active'     AS status
    FROM timetables t
    JOIN timetable_entries te ON te.timetable_id = t.id
    JOIN courses c ON c.id = te.course_id
    WHERE t.status        = 'published'
      AND t.department_id = NEW.department_id
      AND c.department_id = NEW.department_id
      AND te.course_id IS NOT NULL
    ON CONFLICT (student_id, course_id) DO NOTHING;

  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_enroll_on_dept_change ON profiles;

CREATE TRIGGER trg_auto_enroll_on_dept_change
  AFTER UPDATE OF department_id ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_enroll_on_department_change();

-- Backfill: Enroll any existing students who are missing enrollments
-- (catches the student just created before this migration)
INSERT INTO student_enrollments (student_id, course_id, status)
SELECT
  p.id         AS student_id,
  te.course_id AS course_id,
  'active'     AS status
FROM profiles p
JOIN timetables t ON t.department_id = p.department_id AND t.status = 'published'
JOIN timetable_entries te ON te.timetable_id = t.id
JOIN courses c ON c.id = te.course_id AND c.department_id = p.department_id
WHERE p.role      = 'student'
  AND p.is_active = true
  AND te.course_id IS NOT NULL
ON CONFLICT (student_id, course_id) DO NOTHING;
