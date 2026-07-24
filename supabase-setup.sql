-- Family Relay — shared-schedule table (run once in Supabase SQL Editor)
-- Capability model: the unguessable schedule id in the URL (#s=...) IS the secret.
-- Anyone who has the link can read/write that one row; the anon key is public by design.

create table if not exists public.schedules (
  id         text primary key,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.schedules enable row level security;

-- anon = anyone with the publishable key (i.e. anyone loading the page)
drop policy if exists "relay anon read"   on public.schedules;
drop policy if exists "relay anon insert" on public.schedules;
drop policy if exists "relay anon update" on public.schedules;

create policy "relay anon read"   on public.schedules for select to anon using (true);
create policy "relay anon insert" on public.schedules for insert to anon with check (true);
create policy "relay anon update" on public.schedules for update to anon using (true) with check (true);

-- Note: no delete policy on purpose — schedules can't be wiped by the public key.
