-- Appa App Phase 5: sleep hours and walk days, shared only with his consent.
--
-- Run AFTER schema.sql and 002-004. Safe to re-run.
--
-- Shared per day, and only the columns he has switched on: hours slept
-- (minutes) and whether he walked. Step counts, heart rate and bed/wake
-- times never leave his phone.

alter table public.sharing add column if not exists walk boolean not null default false;
alter table public.sharing add column if not exists sleep_hours boolean not null default false;

create or replace function public.shared(p_kind text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case p_kind
              when 'health' then health
              when 'sleep' then sleep
              when 'plan' then plan
              when 'walk' then walk
              when 'sleepHours' then sleep_hours
            end
       from public.sharing where household_id = public.my_household()),
    false);
$$;

create table if not exists public.body_days (
  household_id  uuid not null references public.households (id) on delete cascade,
  day           date not null,
  sleep_minutes int check (sleep_minutes between 0 and 1440),
  walked        boolean,
  primary key (household_id, day)
);
alter table public.body_days enable row level security;

drop policy if exists "read when shared" on public.body_days;
create policy "read when shared" on public.body_days
  for select to authenticated
  using (household_id = public.my_household() and public.is_insider()
         and (public.my_role() = 'appa' or public.shared('walk') or public.shared('sleepHours')));
drop policy if exists "appa writes" on public.body_days;
create policy "appa writes" on public.body_days
  for all to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa')
  with check (household_id = public.my_household() and public.my_role() = 'appa');
