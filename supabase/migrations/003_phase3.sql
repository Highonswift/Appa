-- Appa App Phase 3: story follow-ups, transcripts, pattern alerts.
--
-- Run AFTER schema.sql and 002_phase2.sql. Safe to run more than once.
--
-- Not stored here, by design: companion conversations (never saved
-- anywhere), the companion's memory (kept on his phone, where he can read
-- and delete it), and call history.

alter table public.stories add column if not exists transcript text;

create table if not exists public.story_followups (
  id           uuid primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  story_id     uuid not null references public.stories (id) on delete cascade,
  author_id    uuid not null default auth.uid(),
  author_name  text not null,
  text         text not null,
  used_on      date,
  created_at   timestamptz not null default now()
);

-- A short note, sent only when Appa says yes (or set a standing permission
-- himself). Never a transcript.
create table if not exists public.alerts (
  id              uuid primary key,
  household_id    uuid not null references public.households (id) on delete cascade,
  kind            text not null check (kind in ('badSleep', 'lowMood', 'noCalls')),
  note            text not null check (length(note) <= 300),
  acknowledged_at timestamptz,
  created_at      timestamptz not null default now()
);

create index if not exists followups_household_idx on public.story_followups (household_id, created_at);
create index if not exists alerts_household_idx on public.alerts (household_id, created_at desc);

alter table public.story_followups enable row level security;
alter table public.alerts          enable row level security;

drop policy if exists "household reads followups" on public.story_followups;
create policy "household reads followups" on public.story_followups
  for select to authenticated using (household_id = public.my_household());
drop policy if exists "family adds followups" on public.story_followups;
create policy "family adds followups" on public.story_followups
  for insert to authenticated
  with check (household_id = public.my_household() and author_id = auth.uid()
              and exists (select 1 from public.stories s
                           where s.id = story_id and s.household_id = public.my_household()));
drop policy if exists "appa marks followups used" on public.story_followups;
create policy "appa marks followups used" on public.story_followups
  for update to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa');

drop policy if exists "household reads alerts" on public.alerts;
create policy "household reads alerts" on public.alerts
  for select to authenticated using (household_id = public.my_household());
drop policy if exists "appa sends alerts" on public.alerts;
create policy "appa sends alerts" on public.alerts
  for insert to authenticated
  with check (household_id = public.my_household() and public.my_role() = 'appa');
drop policy if exists "appa resends alerts" on public.alerts;
create policy "appa resends alerts" on public.alerts
  for update to authenticated
  using (household_id = public.my_household() and public.my_role() = 'appa');
drop policy if exists "family acknowledges alerts" on public.alerts;
create policy "family acknowledges alerts" on public.alerts
  for update to authenticated
  using (household_id = public.my_household() and public.my_role() = 'family');
