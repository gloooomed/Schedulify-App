-- ============================================================
-- Schedulify Complete Schema
-- Run this in your Supabase SQL Editor (Project → SQL Editor → New Query)
-- Safe to run on existing databases — uses IF NOT EXISTS / IF NOT EXISTS column checks
-- ============================================================

-- ── Profiles ────────────────────────────────────────────────
create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  full_name       text,
  email           text,
  role            text default 'student', -- admin | faculty | student
  department_id   uuid,
  employee_id     text,
  roll_number     text,
  batch           text,
  semester        text,
  phone           text,
  avatar_url      text,
  is_active       bool default true,
  created_at      timestamptz default now()
);

-- ── Departments ─────────────────────────────────────────────
create table if not exists departments (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  code        text,
  description text,
  head_id     uuid references profiles(id),
  created_at  timestamptz default now()
);

-- ── Courses ──────────────────────────────────────────────────
create table if not exists courses (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  code          text,
  department_id uuid references departments(id),
  credits       int default 3,
  semester      text,
  course_type   text default 'theory', -- theory | lab | tutorial
  is_elective   bool default false,
  description   text,
  created_at    timestamptz default now()
);

-- ── Classrooms ───────────────────────────────────────────────
create table if not exists classrooms (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  capacity     int default 60,
  room_type    text default 'lecture', -- lecture | lab | seminar
  building     text,
  floor        int,
  is_available bool default true,
  created_at   timestamptz default now()
);

-- ── Timetables ───────────────────────────────────────────────
create table if not exists timetables (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  department_id uuid references departments(id),
  academic_year text default '2024-25',
  semester      text default 'odd',
  status        text default 'draft', -- draft | published | archived
  is_active     bool default false,
  generated_by  uuid references profiles(id),
  created_at    timestamptz default now()
);

-- ── Timetable Entries ────────────────────────────────────────
create table if not exists timetable_entries (
  id            uuid primary key default gen_random_uuid(),
  timetable_id  uuid references timetables(id) on delete cascade,
  course_id     uuid references courses(id),
  classroom_id  uuid references classrooms(id),
  faculty_id    uuid references profiles(id),
  day_of_week   int, -- 1=Mon ... 6=Sat
  start_time    text, -- HH:mm
  end_time      text,
  session_type  text default 'lecture',
  student_group text
);

-- ── Student Enrollments ──────────────────────────────────────
create table if not exists student_enrollments (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid references profiles(id),
  course_id  uuid references courses(id),
  status     text default 'active', -- active | dropped
  created_at timestamptz default now()
);

-- ── Row Level Security ───────────────────────────────────────
do $$ begin
  -- profiles
  if not exists (select from pg_policies where tablename='profiles' and policyname='Allow all') then
    alter table profiles enable row level security;
    create policy "Allow all" on profiles for all using (true) with check (true);
  end if;
  -- departments
  if not exists (select from pg_policies where tablename='departments' and policyname='Allow all') then
    alter table departments enable row level security;
    create policy "Allow all" on departments for all using (true) with check (true);
  end if;
  -- courses
  if not exists (select from pg_policies where tablename='courses' and policyname='Allow all') then
    alter table courses enable row level security;
    create policy "Allow all" on courses for all using (true) with check (true);
  end if;
  -- classrooms
  if not exists (select from pg_policies where tablename='classrooms' and policyname='Allow all') then
    alter table classrooms enable row level security;
    create policy "Allow all" on classrooms for all using (true) with check (true);
  end if;
  -- timetables
  if not exists (select from pg_policies where tablename='timetables' and policyname='Allow all') then
    alter table timetables enable row level security;
    create policy "Allow all" on timetables for all using (true) with check (true);
  end if;
  -- timetable_entries
  if not exists (select from pg_policies where tablename='timetable_entries' and policyname='Allow all') then
    alter table timetable_entries enable row level security;
    create policy "Allow all" on timetable_entries for all using (true) with check (true);
  end if;
  -- student_enrollments
  if not exists (select from pg_policies where tablename='student_enrollments' and policyname='Allow all') then
    alter table student_enrollments enable row level security;
    create policy "Allow all" on student_enrollments for all using (true) with check (true);
  end if;
end $$;


-- ============================================================
-- ATTENDANCE SYSTEM — v2
-- Added: geofence_config, attendance_sessions,
--        attendance_records, attendance_audit_logs, mark_attendance RPC
-- ============================================================

-- ── Geofence Config ──────────────────────────────────────────
-- Admin-defined campus boundary polygon, configured in-app.
create table if not exists geofence_config (
  id             uuid        primary key default gen_random_uuid(),
  name           text        not null default 'Campus Geofence',
  polygon_points jsonb       not null,  -- [{"lat": 22.123, "lng": 88.456}, ...]
  is_active      bool        not null default true,
  created_by     uuid        references profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Only one active geofence at a time
create unique index if not exists geofence_one_active
  on geofence_config (is_active)
  where is_active = true;

-- ── Attendance Sessions ──────────────────────────────────────
-- One session per timetable slot per day.
-- QR hash rotates every 5 seconds from the faculty client.
create table if not exists attendance_sessions (
  id                 uuid        primary key default gen_random_uuid(),
  timetable_entry_id uuid        not null references timetable_entries(id) on delete cascade,
  faculty_id         uuid        not null references profiles(id),
  department_id      uuid        references departments(id),
  course_id          uuid        references courses(id),
  session_date       date        not null default current_date,
  started_at         timestamptz not null default now(),
  ended_at           timestamptz,
  status             text        not null default 'active'
                                 check (status in ('active', 'ended', 'cancelled')),
  current_qr_hash    text,
  qr_updated_at      timestamptz,
  unique (timetable_entry_id, session_date)
);

create index if not exists idx_sessions_faculty
  on attendance_sessions (faculty_id, session_date);
create index if not exists idx_sessions_status
  on attendance_sessions (status);

-- ── Attendance Records ───────────────────────────────────────
-- One row per student per session.
-- UNIQUE (session_id, student_id) prevents duplicate check-ins at DB level.
create table if not exists attendance_records (
  id            uuid        primary key default gen_random_uuid(),
  session_id    uuid        not null references attendance_sessions(id) on delete cascade,
  student_id    uuid        not null references profiles(id),
  marked_at     timestamptz not null default now(),
  status        text        not null default 'present'
                            check (status in ('present', 'absent', 'late', 'excused')),
  location_data jsonb,       -- {"lat": 22.1, "lng": 88.4, "is_mocked": false, "accuracy": 12.5}
  qr_hash_used  text,
  is_override   bool        not null default false,
  unique (session_id, student_id)
);

create index if not exists idx_records_student  on attendance_records (student_id);
create index if not exists idx_records_session  on attendance_records (session_id);

-- ── Attendance Audit Logs ────────────────────────────────────
-- Every admin override or session termination is logged here.
create table if not exists attendance_audit_logs (
  id         uuid        primary key default gen_random_uuid(),
  record_id  uuid        references attendance_records(id) on delete set null,
  session_id uuid        references attendance_sessions(id) on delete set null,
  admin_id   uuid        not null references profiles(id),
  action     text        not null,  -- 'override_present' | 'override_absent' | 'override_late' | 'override_excused' | 'terminate_session'
  reason     text        not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_session on attendance_audit_logs (session_id);
create index if not exists idx_audit_admin   on attendance_audit_logs (admin_id, created_at desc);

-- ── RPC: mark_attendance ─────────────────────────────────────
create or replace function mark_attendance(
  p_session_id uuid,
  p_student_id uuid,
  p_qr_hash    text,
  p_lat        float,
  p_lng        float,
  p_is_mocked  boolean
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_session   attendance_sessions%rowtype;
  v_record_id uuid;
begin
  -- Block mocked / spoofed GPS
  if p_is_mocked then
    return jsonb_build_object('success', false, 'error', 'mock_location');
  end if;

  -- Fetch active session
  select * into v_session
    from attendance_sessions
   where id = p_session_id and status = 'active';

  if not found then
    return jsonb_build_object('success', false, 'error', 'session_not_active');
  end if;

  -- Validate QR hash is current and < 10s old (5s rotation + 5s grace)
  if v_session.current_qr_hash is null or
     v_session.current_qr_hash <> p_qr_hash or
     v_session.qr_updated_at < now() - interval '10 seconds'
  then
    return jsonb_build_object('success', false, 'error', 'invalid_qr');
  end if;

  -- Insert; ON CONFLICT handles duplicate scan attempts silently
  insert into attendance_records
    (session_id, student_id, status, location_data, qr_hash_used)
  values (
    p_session_id,
    p_student_id,
    'present',
    jsonb_build_object('lat', p_lat, 'lng', p_lng, 'is_mocked', p_is_mocked),
    p_qr_hash
  )
  on conflict (session_id, student_id) do nothing
  returning id into v_record_id;

  if v_record_id is null then
    return jsonb_build_object('success', false, 'error', 'already_marked');
  end if;

  return jsonb_build_object('success', true, 'record_id', v_record_id);
end;
$$;

-- ── RLS for Attendance Tables ────────────────────────────────
do $$ begin
  -- geofence_config: all authenticated can read; admin can write
  if not exists (select from pg_policies where tablename='geofence_config' and policyname='authenticated_read_geofence') then
    alter table geofence_config enable row level security;
    create policy "authenticated_read_geofence"
      on geofence_config for select using (auth.role() = 'authenticated');
    create policy "admin_manage_geofence"
      on geofence_config for all
      using (exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'super_admin')));
  end if;

  -- attendance_sessions: all authenticated can read; faculty/admin can write
  if not exists (select from pg_policies where tablename='attendance_sessions' and policyname='authenticated_read_sessions') then
    alter table attendance_sessions enable row level security;
    create policy "authenticated_read_sessions"
      on attendance_sessions for select using (auth.role() = 'authenticated');
    create policy "faculty_manage_own_sessions"
      on attendance_sessions for all
      using (faculty_id = auth.uid() or
             exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'super_admin')));
  end if;

  -- attendance_records: students see own; faculty/admin see all
  if not exists (select from pg_policies where tablename='attendance_records' and policyname='student_own_or_staff_all') then
    alter table attendance_records enable row level security;
    create policy "student_own_or_staff_all"
      on attendance_records for select
      using (student_id = auth.uid() or
             exists (select 1 from profiles where id = auth.uid() and role in ('faculty', 'admin', 'super_admin')));
    create policy "admin_override_records"
      on attendance_records for update
      using (exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'super_admin')));
  end if;

  -- attendance_audit_logs: admin only
  if not exists (select from pg_policies where tablename='attendance_audit_logs' and policyname='admin_only_audit') then
    alter table attendance_audit_logs enable row level security;
    create policy "admin_only_audit"
      on attendance_audit_logs for all
      using (exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'super_admin')));
  end if;
end $$;

-- ── Realtime ─────────────────────────────────────────────────
-- Live attendee count on faculty QR projection screen
alter publication supabase_realtime add table attendance_sessions;
alter publication supabase_realtime add table attendance_records;
