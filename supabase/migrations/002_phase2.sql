-- Appa App Phase 2: question board, daily plan, health log, sleep, sharing.
--
-- Run AFTER supabase/schema.sql (Phase 1). Safe to run more than once.
-- Dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Consent model (roadmap: "Appa owns his data"): Appa's phone writes health,
-- sleep and plan rows only while he has turned that item on, and deletes
-- them when he turns it off. The policies below also refuse family reads of
-- anything he has not shared, so a stale row can never leak.

create table if not exists public.sharing (
  household_id uuid primary key references public.households (id) on delete cascade,
  health boolean not null default false,
  sleep  boolean not null default false,
  plan   boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.questions (
  id           uuid primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  author_id    uuid not null default auth.uid(),
  author_name  text not null,
  text         text,
  audio_path   text,
  answer_path  text,
  answered_at  timestamptz,
  created_at   timestamptz not null default now(),
  check (text is not null or audio_path is not null)
);

create table if not exists public.plan_items (
  id           uuid primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  day          date not null,
  text         text not null,
  done         boolean not null default false,
  added_by     text,
  created_at   timestamptz not null default now()
);

-- One request per family member per day (roadmap: "Amma can add one item a day").
create table if not exists public.plan_requests (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  author_id    uuid not null default auth.uid(),
  author_name  text not null,
  day          date not null,
  text         text not null,
  created_at   timestamptz not null default now(),
  unique (household_id, author_id, day)
);

create table if not exists public.health_entries (
  id           uuid primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  at           timestamptz not null,
  kind         text not null check (kind in ('bp', 'sugarFasting', 'sugarAfterFood')),
  value        int not null,
  value2       int
);

create table if not exists public.sleep_entries (
  household_id uuid not null references public.households (id) on delete cascade,
  day          date not null,
  rating       text not null check (rating in ('good', 'okay', 'bad')),
  recorded_at  timestamptz not null,
  primary key (household_id, day)
);

create index if not exists questions_household_idx on public.questions (household_id, created_at desc);
create index if not exists plan_items_household_idx on public.plan_items (household_id, day);
create index if not exists health_household_idx on public.health_entries (household_id, at);

-- Has Appa shared this kind of data with his household?
create or replace function public.shared(p_kind text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case p_kind when 'health' then health when 'sleep' then sleep when 'plan' then plan end
       from public.sharing where household_id = public.my_household()),
    false);
$$;
grant execute on function public.shared(text) to authenticated;

alter table public.sharing        enable row level security;
alter table public.questions      enable row level security;
alter table public.plan_items     enable row level security;
alter table public.plan_requests  enable row level security;
alter table public.health_entries enable row level security;
alter table public.sleep_entries  enable row level security;

-- sharing: everyone in the household reads it; only Appa's phone changes it.
drop policy if exists "household reads sharing" on public.sharing;
create policy "household reads sharing" on public.sharing
  for select to authenticated using (household_id = public.my_household());
drop policy if exists "appa writes sharing" on public.sharing;
create policy "appa writes sharing" on public.sharing
  for all to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa')
  with check (household_id = public.my_household() and public.my_role() = 'appa');

-- questions: family ask, Appa answers, everyone in the household reads.
drop policy if exists "household reads questions" on public.questions;
create policy "household reads questions" on public.questions
  for select to authenticated using (household_id = public.my_household());
drop policy if exists "family asks questions" on public.questions;
create policy "family asks questions" on public.questions
  for insert to authenticated
  with check (household_id = public.my_household() and author_id = auth.uid());
drop policy if exists "appa answers questions" on public.questions;
create policy "appa answers questions" on public.questions
  for update to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa');

-- health, sleep, plan: Appa's phone writes; family read only when shared.
do $$
declare t text; k text;
begin
  foreach t in array array['health_entries', 'sleep_entries', 'plan_items'] loop
    k := case t when 'health_entries' then 'health' when 'sleep_entries' then 'sleep' else 'plan' end;
    execute format('drop policy if exists "read when shared" on public.%I', t);
    execute format($p$create policy "read when shared" on public.%I for select to authenticated
      using (household_id = public.my_household() and (public.my_role() = 'appa' or public.shared(%L)))$p$, t, k);
    execute format('drop policy if exists "appa writes" on public.%I', t);
    execute format($p$create policy "appa writes" on public.%I for all to authenticated
      using (household_id = public.my_household() and public.my_role() = 'appa')
      with check (household_id = public.my_household() and public.my_role() = 'appa')$p$, t);
  end loop;
end $$;

-- plan requests: family insert their own; Appa's phone reads and removes them.
drop policy if exists "family requests plan items" on public.plan_requests;
create policy "family requests plan items" on public.plan_requests
  for insert to authenticated
  with check (household_id = public.my_household() and author_id = auth.uid());
drop policy if exists "read own or appa" on public.plan_requests;
create policy "read own or appa" on public.plan_requests
  for select to authenticated
  using (household_id = public.my_household() and (author_id = auth.uid() or public.my_role() = 'appa'));
drop policy if exists "appa takes requests" on public.plan_requests;
create policy "appa takes requests" on public.plan_requests
  for delete to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa');
