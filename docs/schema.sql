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
