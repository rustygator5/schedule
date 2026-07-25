-- Family Schedule — SECURITY HARDENING  (run once, in the Supabase SQL Editor)
--
-- WHY THIS EXISTS
-- The original policies said `to anon using (true)`, which means "any anonymous
-- caller may read EVERY row". The publishable key is public (it ships in the
-- page source), so anyone could list every schedule id and read every family's
-- kids, home addresses and activity times. The unguessable link was a UI
-- convention only — the database was never told to require it.
--
-- THE FIX
-- Take away direct table access and expose only functions that REQUIRE the
-- schedule id as an argument. No id, no data. The id (~88 bits) is not
-- brute-forceable, so the capability model is now actually enforced.
--
-- Safe to re-run.

-- ── 1. Remove the permissive access ──────────────────────────────────────────
drop policy if exists "relay anon read"   on public.schedules;
drop policy if exists "relay anon insert" on public.schedules;
drop policy if exists "relay anon update" on public.schedules;
revoke all on public.schedules from anon, authenticated;

do $$ begin
  if to_regclass('public.schedule_snapshots') is not null then
    execute 'drop policy if exists "snap anon read"   on public.schedule_snapshots';
    execute 'drop policy if exists "snap anon insert" on public.schedule_snapshots';
    execute 'drop policy if exists "snap anon delete" on public.schedule_snapshots';
    execute 'revoke all on public.schedule_snapshots from anon, authenticated';
  end if;
end $$;

-- RLS stays on; with no policies and no grants, direct table access returns nothing.
alter table public.schedules enable row level security;

-- ── 2. Reject weak ids (so nobody can squat a guessable schedule) ────────────
create or replace function public.fs_valid_id(p_id text)
returns boolean language sql immutable as $$
  select p_id is not null and p_id ~ '^[A-Za-z0-9_-]{12,64}$';
$$;

-- ── 3. The only way in: functions that demand the id ─────────────────────────
create or replace function public.schedule_get(p_id text)
returns table(data jsonb, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select s.data, s.updated_at from public.schedules s where s.id = p_id;
$$;

create or replace function public.schedule_save(p_id text, p_data jsonb)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare ts timestamptz := now();
begin
  if not public.fs_valid_id(p_id) then raise exception 'invalid schedule id'; end if;
  if pg_column_size(p_data) > 4000000 then raise exception 'schedule too large'; end if;
  insert into public.schedules (id, data, updated_at) values (p_id, p_data, ts)
  on conflict (id) do update set data = excluded.data, updated_at = ts;
  return ts;
end $$;

-- ── 4. Snapshots, same rule: every call is scoped to one schedule id ─────────
do $$ begin
  if to_regclass('public.schedule_snapshots') is null then return; end if;

  execute $f$
    create or replace function public.snapshot_add(p_id text, p_data jsonb)
    returns void language plpgsql security definer set search_path = public as $b$
    begin
      if not public.fs_valid_id(p_id) then raise exception 'invalid schedule id'; end if;
      insert into public.schedule_snapshots (schedule_id, data) values (p_id, p_data);
    end $b$;
  $f$;

  execute $f$
    create or replace function public.snapshot_list(p_id text)
    returns table(id bigint, created_at timestamptz)
    language sql security definer set search_path = public as $b$
      select s.id, s.created_at from public.schedule_snapshots s
      where s.schedule_id = p_id order by s.created_at desc limit 50;
    $b$;
  $f$;

  -- note the schedule_id check: without it, a bare row number would leak
  -- another family's snapshot.
  execute $f$
    create or replace function public.snapshot_get(p_id text, p_snap bigint)
    returns jsonb language sql security definer set search_path = public as $b$
      select s.data from public.schedule_snapshots s
      where s.id = p_snap and s.schedule_id = p_id;
    $b$;
  $f$;

  execute $f$
    create or replace function public.snapshot_prune(p_id text, p_keep int)
    returns void language sql security definer set search_path = public as $b$
      delete from public.schedule_snapshots d
      where d.schedule_id = p_id and d.id not in (
        select s.id from public.schedule_snapshots s
        where s.schedule_id = p_id order by s.created_at desc limit greatest(p_keep, 1)
      );
    $b$;
  $f$;
end $$;

-- ── 5. Let the app (anon) call them, and nothing else ────────────────────────
grant execute on function public.schedule_get(text)          to anon;
grant execute on function public.schedule_save(text, jsonb)  to anon;
do $$ begin
  if to_regclass('public.schedule_snapshots') is not null then
    execute 'grant execute on function public.snapshot_add(text, jsonb) to anon';
    execute 'grant execute on function public.snapshot_list(text) to anon';
    execute 'grant execute on function public.snapshot_get(text, bigint) to anon';
    execute 'grant execute on function public.snapshot_prune(text, int) to anon';
  end if;
end $$;

-- ── Verify: this must now return ZERO rows (enumeration is dead) ─────────────
-- select * from public.schedules;   -- run as anon via the REST API
