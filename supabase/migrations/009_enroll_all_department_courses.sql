-- Migration 009: Enroll students in all department courses, ignoring timetables
-- The requirement is that any student in a branch should be enrolled in ALL courses for that branch,
-- not just the ones in the currently published timetable.

-- 1. When a student is created, enroll them in all courses for their department
CREATE OR REPLACE FUNCTION auto_enroll_on_student_create()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.role = 'student' AND NEW.department_id IS NOT NULL THEN
    INSERT INTO student_enrollments (student_id, course_id, status)
    SELECT
      NEW.id       AS student_id,
      c.id         AS course_id,
      'active'     AS status
    FROM courses c
    WHERE c.department_id = NEW.department_id
    ON CONFLICT (student_id, course_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- 2. When a student's department changes, update their enrollments to the new department's courses
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

    -- Enroll in the NEW department's courses
    INSERT INTO student_enrollments (student_id, course_id, status)
    SELECT
      NEW.id       AS student_id,
      c.id         AS course_id,
      'active'     AS status
    FROM courses c
    WHERE c.department_id = NEW.department_id
    ON CONFLICT (student_id, course_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

-- 3. When a new course is created, enroll all existing students in that department
CREATE OR REPLACE FUNCTION auto_enroll_on_course_create()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.department_id IS NOT NULL THEN
    INSERT INTO student_enrollments (student_id, course_id, status)
    SELECT
      p.id         AS student_id,
      NEW.id       AS course_id,
      'active'     AS status
    FROM profiles p
    WHERE p.role = 'student'
      AND p.department_id = NEW.department_id
      AND p.is_active = true
    ON CONFLICT (student_id, course_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_enroll_on_course_create ON courses;
CREATE TRIGGER trg_auto_enroll_on_course_create
  AFTER INSERT ON courses
  FOR EACH ROW
  EXECUTE FUNCTION auto_enroll_on_course_create();

-- 4. Backfill: Immediately enroll all existing students in all their department's courses
INSERT INTO student_enrollments (student_id, course_id, status)
SELECT
  p.id         AS student_id,
  c.id         AS course_id,
  'active'     AS status
FROM profiles p
JOIN courses c ON c.department_id = p.department_id
WHERE p.role = 'student'
  AND p.is_active = true
ON CONFLICT (student_id, course_id) DO NOTHING;
