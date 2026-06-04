-- ============================================================
-- Migration v2: Attendance System
-- Run this if you already have the base schema (schema.sql / migration_v1.sql)
-- Safe to re-run — all statements use IF NOT EXISTS guards
-- ============================================================

-- ── 1. Geofence Config ───────────────────────────────────────
create table if not exists geofence_config (
  id             uuid        primary key default gen_random_uuid(),
  name           text        not null default 'Campus Geofence',
  polygon_points jsonb       not null,
  is_active      bool        not null default true,
  created_by     uuid        references profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create unique index if not exists geofence_one_active
  on geofence_config (is_active) where is_active = true;

-- ── 2. Attendance Sessions ───────────────────────────────────
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

create index if not exists idx_sessions_faculty on attendance_sessions (faculty_id, session_date);
create index if not exists idx_sessions_status  on attendance_sessions (status);

-- ── 3. Attendance Records ────────────────────────────────────
create table if not exists attendance_records (
  id            uuid        primary key default gen_random_uuid(),
  session_id    uuid        not null references attendance_sessions(id) on delete cascade,
  student_id    uuid        not null references profiles(id),
  marked_at     timestamptz not null default now(),
  status        text        not null default 'present'
                            check (status in ('present', 'absent', 'late', 'excused')),
  location_data jsonb,
  qr_hash_used  text,
  is_override   bool        not null default false,
  unique (session_id, student_id)
);

create index if not exists idx_records_student on attendance_records (student_id);
create index if not exists idx_records_session on attendance_records (session_id);

-- ── 4. Attendance Audit Logs ─────────────────────────────────
create table if not exists attendance_audit_logs (
  id         uuid        primary key default gen_random_uuid(),
  record_id  uuid        references attendance_records(id) on delete set null,
  session_id uuid        references attendance_sessions(id) on delete set null,
  admin_id   uuid        not null references profiles(id),
  action     text        not null,
  reason     text        not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_session on attendance_audit_logs (session_id);
create index if not exists idx_audit_admin   on attendance_audit_logs (admin_id, created_at desc);

-- ── 5. RPC: mark_attendance ──────────────────────────────────
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
  if p_is_mocked then
    return jsonb_build_object('success', false, 'error', 'mock_location');
  end if;

  select * into v_session
    from attendance_sessions
   where id = p_session_id and status = 'active';

  if not found then
    return jsonb_build_object('success', false, 'error', 'session_not_active');
  end if;

  if v_session.current_qr_hash is null or
     v_session.current_qr_hash <> p_qr_hash or
     v_session.qr_updated_at < now() - interval '10 seconds'
  then
    return jsonb_build_object('success', false, 'error', 'invalid_qr');
  end if;

  insert into attendance_records
    (session_id, student_id, status, location_data, qr_hash_used)
  values (
    p_session_id, p_student_id, 'present',
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

-- ── 6. RLS ───────────────────────────────────────────────────
do $$ begin
  if not exists (select from pg_policies where tablename='geofence_config' and policyname='authenticated_read_geofence') then
    alter table geofence_config enable row level security;
    create policy "authenticated_read_geofence"
      on geofence_config for select using (auth.role() = 'authenticated');
    create policy "admin_manage_geofence"
      on geofence_config for all
      using (exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'super_admin')));
  end if;

  if not exists (select from pg_policies where tablename='attendance_sessions' and policyname='authenticated_read_sessions') then
    alter table attendance_sessions enable row level security;
    create policy "authenticated_read_sessions"
      on attendance_sessions for select using (auth.role() = 'authenticated');
    create policy "faculty_manage_own_sessions"
      on attendance_sessions for all
      using (faculty_id = auth.uid() or
             exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'super_admin')));
  end if;

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

  if not exists (select from pg_policies where tablename='attendance_audit_logs' and policyname='admin_only_audit') then
    alter table attendance_audit_logs enable row level security;
    create policy "admin_only_audit"
      on attendance_audit_logs for all
      using (exists (select 1 from profiles where id = auth.uid() and role in ('admin', 'super_admin')));
  end if;
end $$;

-- ── 7. Realtime ──────────────────────────────────────────────
alter publication supabase_realtime add table attendance_sessions;
alter publication supabase_realtime add table attendance_records;

-- ============================================================
-- Done. Verify 4 new tables appear in Supabase Table Editor.
-- ============================================================
