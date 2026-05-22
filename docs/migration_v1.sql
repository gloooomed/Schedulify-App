-- ============================================================
-- Migration: Add missing columns to existing Schedulify tables
-- Run this in Supabase SQL Editor if you already ran the initial schema
-- ============================================================

-- departments: add description, head_id
alter table departments add column if not exists description text;
alter table departments add column if not exists head_id uuid references profiles(id);
alter table departments add column if not exists code text;

-- courses: add full fields
alter table courses add column if not exists semester text;
alter table courses add column if not exists course_type text default 'theory';
alter table courses add column if not exists is_elective bool default false;
alter table courses add column if not exists description text;

-- classrooms: add room_type, building, floor
alter table classrooms add column if not exists room_type text default 'lecture';
alter table classrooms add column if not exists building text;
alter table classrooms add column if not exists floor int;

-- timetables: add full fields
alter table timetables add column if not exists department_id uuid references departments(id);
alter table timetables add column if not exists academic_year text default '2024-25';
alter table timetables add column if not exists semester text default 'odd';
alter table timetables add column if not exists is_active bool default false;
alter table timetables add column if not exists generated_by uuid references profiles(id);

-- profiles: add missing fields
alter table profiles add column if not exists employee_id text;
alter table profiles add column if not exists roll_number text;
alter table profiles add column if not exists batch text;
alter table profiles add column if not exists semester text;
alter table profiles add column if not exists phone text;
alter table profiles add column if not exists avatar_url text;
alter table profiles add column if not exists is_active bool default true;
alter table profiles add column if not exists department_id uuid references departments(id);

-- rename enrollments → student_enrollments (if you created it as enrollments)
-- skip if your table is already named student_enrollments
do $$ begin
  if exists (select from information_schema.tables where table_name = 'enrollments')
  and not exists (select from information_schema.tables where table_name = 'student_enrollments')
  then
    alter table enrollments rename to student_enrollments;
    alter table student_enrollments add column if not exists status text default 'active';
  end if;
end $$;

-- create student_enrollments fresh if neither exists
create table if not exists student_enrollments (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid references profiles(id),
  course_id  uuid references courses(id),
  status     text default 'active',
  created_at timestamptz default now()
);

do $$ begin
  if not exists (select from pg_policies where tablename='student_enrollments' and policyname='Allow all') then
    alter table student_enrollments enable row level security;
    create policy "Allow all" on student_enrollments for all using (true) with check (true);
  end if;
end $$;
