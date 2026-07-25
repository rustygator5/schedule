-- Family Schedule — backup snapshots (run once in the Supabase SQL Editor)
-- Safety net for the shared-link model: anyone with the link can edit everything,
-- so keep restorable copies. Same capability model as the schedules table —
-- you can only reach snapshots whose schedule_id you already know.

create table if not exists public.schedule_snapshots (
  id          bigserial primary key,
  schedule_id text        not null,
  data        jsonb       not null,
  created_at  timestamptz not null default now()
);

create index if not exists schedule_snapshots_sched_idx
  on public.schedule_snapshots (schedule_id, created_at desc);

alter table public.schedule_snapshots enable row level security;

drop policy if exists "snap anon read"   on public.schedule_snapshots;
drop policy if exists "snap anon insert" on public.schedule_snapshots;
drop policy if exists "snap anon delete" on public.schedule_snapshots;

create policy "snap anon read"   on public.schedule_snapshots for select to anon using (true);
create policy "snap anon insert" on public.schedule_snapshots for insert to anon with check (true);
-- delete is needed so the app can prune old snapshots down to the newest 20
create policy "snap anon delete" on public.schedule_snapshots for delete to anon using (true);
