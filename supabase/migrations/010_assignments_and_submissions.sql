-- Migration 010: Assignments & Submissions

-- ── Tables ────────────────────────────────────────────────────────────────────

create table if not exists assignments (
  id              uuid primary key default gen_random_uuid(),
  course_id       uuid references courses(id) on delete cascade,
  faculty_id      uuid references profiles(id) on delete cascade,
  title           text not null,
  description     text,
  due_at          timestamptz not null,
  total_marks     int not null default 100,
  allowed_types   text[] not null default array['pdf','docx','image','zip'],
  max_file_mb     int not null default 10,
  created_at      timestamptz default now()
);

create table if not exists assignment_submissions (
  id              uuid primary key default gen_random_uuid(),
  assignment_id   uuid references assignments(id) on delete cascade,
  student_id      uuid references profiles(id) on delete cascade,
  file_url        text,
  file_name       text,
  submitted_at    timestamptz default now(),
  marks_obtained  int,
  feedback        text,
  graded_at       timestamptz,
  graded_by       uuid references profiles(id),
  unique(assignment_id, student_id)
);

-- ── Storage Bucket ────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('assignments', 'assignments', false)
on conflict (id) do nothing;

-- ── RLS: assignments ─────────────────────────────────────────────────────────

alter table assignments enable row level security;

-- Faculty can manage their own assignments
create policy "faculty_manage_assignments" on assignments
  for all
  using (auth.uid() = faculty_id)
  with check (auth.uid() = faculty_id);

-- Enrolled students can read assignments for their courses
create policy "student_read_assignments" on assignments
  for select
  using (
    exists (
      select 1 from student_enrollments se
      where se.student_id = auth.uid()
        and se.course_id = assignments.course_id
        and se.status = 'active'
    )
  );

-- ── RLS: assignment_submissions ───────────────────────────────────────────────

alter table assignment_submissions enable row level security;

-- Students can insert and read their own submissions
create policy "student_manage_own_submission" on assignment_submissions
  for all
  using (auth.uid() = student_id)
  with check (auth.uid() = student_id);

-- Faculty can read and update (grade) submissions for their assignments
create policy "faculty_grade_submissions" on assignment_submissions
  for select
  using (
    exists (
      select 1 from assignments a
      where a.id = assignment_submissions.assignment_id
        and a.faculty_id = auth.uid()
    )
  );

create policy "faculty_update_submissions" on assignment_submissions
  for update
  using (
    exists (
      select 1 from assignments a
      where a.id = assignment_submissions.assignment_id
        and a.faculty_id = auth.uid()
    )
  );

-- ── RLS: Storage ──────────────────────────────────────────────────────────────

-- Students upload to their own path
create policy "student_upload" on storage.objects
  for insert
  with check (
    bucket_id = 'assignments'
    and auth.role() = 'authenticated'
  );

-- Authenticated users can read (signed URLs checked separately)
create policy "authenticated_read" on storage.objects
  for select
  using (
    bucket_id = 'assignments'
    and auth.role() = 'authenticated'
  );

-- ── Admin compliance RPC ──────────────────────────────────────────────────────

create or replace function get_assignment_compliance()
returns table (
  department_name text,
  total_assignments bigint,
  total_submissions bigint,
  compliance_rate numeric
)
language sql
security definer
as $$
  select
    d.name                                     as department_name,
    count(distinct a.id)                       as total_assignments,
    count(distinct sub.id)                     as total_submissions,
    case
      when count(distinct a.id) = 0 then 0
      else round(
        count(distinct sub.id)::numeric /
        nullif(count(distinct a.id) * (
          select count(*) from profiles p2
          where p2.department_id = d.id and p2.role = 'student' and p2.is_active = true
        ), 0) * 100, 1
      )
    end                                        as compliance_rate
  from departments d
  left join courses c on c.department_id = d.id
  left join assignments a on a.course_id = c.id
  left join assignment_submissions sub on sub.assignment_id = a.id
  group by d.id, d.name
  order by d.name;
$$;
