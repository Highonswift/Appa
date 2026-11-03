-- Appa App Phase 4: help others, local events, TNSTC retirees circle.
--
-- Run AFTER schema.sql, 002_phase2.sql and 003_phase3.sql. Safe to re-run.
--
-- Phase 4 lets people OUTSIDE the family in, so this migration first closes
-- every family table to them:
--   * "guest" = a helper who joined with Appa's help code. A guest can ask
--     him questions and hear his answers to THEIR OWN questions. Nothing else:
--     no stories, replies, plan, health, sleep, alerts, events, members, codes.
--   * Circle members (old colleagues) are not household members at all; the
--     circle has its own tables and its own storage bucket.
-- Repair diary and household ledger stay on his phone (not stored here).

-- ---------------------------------------------------------------- roles

alter table public.members drop constraint if exists members_role_check;
alter table public.members add constraint members_role_check check (role in ('appa', 'family', 'guest'));

-- Appa or family (not a guest) of the signed-in user's household.
create or replace function public.is_insider()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role in ('appa', 'family') from public.members where user_id = auth.uid()), false);
$$;
grant execute on function public.is_insider() to authenticated;

-- ---------------------------------------------------------------- re-close Phase 1-3 tables to guests

drop policy if exists "members see own household" on public.households;
create policy "members see own household" on public.households
  for select to authenticated using (id = public.my_household() and public.is_insider());

drop policy if exists "members see household members" on public.members;
create policy "members see household members" on public.members
  for select to authenticated using (household_id = public.my_household() and public.is_insider());

drop policy if exists "household reads stories" on public.stories;
create policy "household reads stories" on public.stories
  for select to authenticated using (household_id = public.my_household() and public.is_insider());

drop policy if exists "household reads replies" on public.replies;
create policy "household reads replies" on public.replies
  for select to authenticated using (household_id = public.my_household() and public.is_insider());
drop policy if exists "family writes replies" on public.replies;
create policy "family writes replies" on public.replies
  for insert to authenticated
  with check (household_id = public.my_household() and public.is_insider()
              and exists (select 1 from public.stories s
                           where s.id = story_id and s.household_id = public.my_household()));

drop policy if exists "household reads sharing" on public.sharing;
create policy "household reads sharing" on public.sharing
  for select to authenticated using (household_id = public.my_household() and public.is_insider());

do $$
declare t text; k text;
begin
  foreach t in array array['health_entries', 'sleep_entries', 'plan_items'] loop
    k := case t when 'health_entries' then 'health' when 'sleep_entries' then 'sleep' else 'plan' end;
    execute format('drop policy if exists "read when shared" on public.%I', t);
    execute format($p$create policy "read when shared" on public.%I for select to authenticated
      using (household_id = public.my_household() and public.is_insider()
             and (public.my_role() = 'appa' or public.shared(%L)))$p$, t, k);
  end loop;
end $$;

drop policy if exists "family requests plan items" on public.plan_requests;
create policy "family requests plan items" on public.plan_requests
  for insert to authenticated
  with check (household_id = public.my_household() and public.is_insider() and author_id = auth.uid());

drop policy if exists "household reads followups" on public.story_followups;
create policy "household reads followups" on public.story_followups
  for select to authenticated using (household_id = public.my_household() and public.is_insider());
drop policy if exists "family adds followups" on public.story_followups;
create policy "family adds followups" on public.story_followups
  for insert to authenticated
  with check (household_id = public.my_household() and public.is_insider() and author_id = auth.uid()
              and exists (select 1 from public.stories s
                           where s.id = story_id and s.household_id = public.my_household()));

drop policy if exists "household reads alerts" on public.alerts;
create policy "household reads alerts" on public.alerts
  for select to authenticated using (household_id = public.my_household() and public.is_insider());

-- ---------------------------------------------------------------- help others (questions from outside)

alter table public.questions add column if not exists outside boolean not null default false;
alter table public.questions add column if not exists topic text;

-- Insiders see every question; a guest sees only their own.
drop policy if exists "household reads questions" on public.questions;
create policy "household reads questions" on public.questions
  for select to authenticated
  using (household_id = public.my_household() and (public.is_insider() or author_id = auth.uid()));

-- Family ask as family; guests can only ask as outsiders.
drop policy if exists "family asks questions" on public.questions;
create policy "family asks questions" on public.questions
  for insert to authenticated
  with check (household_id = public.my_household() and author_id = auth.uid()
              and (public.is_insider() or outside));

alter table public.households add column if not exists help_code text unique;

-- Appa's phone: the help code (made once, then the same).
create or replace function public.help_code()
returns text language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare v_code text; v_hh uuid; v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if public.my_role() is distinct from 'appa' then raise exception 'only Appa''s phone makes the help code'; end if;
  v_hh := public.my_household();
  select help_code into v_code from public.households where id = v_hh;
  if v_code is not null then return v_code; end if;
  loop
    v_code := 'H';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.households where households.help_code = v_code);
  end loop;
  update public.households set help_code = v_code where id = v_hh;
  return v_code;
end;
$$;

-- ---------------------------------------------------------------- storage: family voice bucket

drop policy if exists "household voice read" on storage.objects;
create policy "household voice read" on storage.objects
  for select to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = public.my_household()::text
         and (public.is_insider()
              or ((storage.foldername(name))[2] = 'answers'
                  and exists (select 1 from public.questions q
                               where q.id::text = split_part(storage.filename(name), '.', 1)
                                 and q.author_id = auth.uid()))));

drop policy if exists "household voice write" on storage.objects;
create policy "household voice write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'voice' and (storage.foldername(name))[1] = public.my_household()::text
              and (public.is_insider() or (storage.foldername(name))[2] = 'questions'));

drop policy if exists "household voice update" on storage.objects;
create policy "household voice update" on storage.objects
  for update to authenticated
  using (bucket_id = 'voice' and (storage.foldername(name))[1] = public.my_household()::text
         and public.is_insider());

-- ---------------------------------------------------------------- local events (family curated)

create table if not exists public.events (
  id           uuid primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  title        text not null,
  place        text not null default '',
  starts_at    timestamptz not null,
  note         text not null default '',
  added_by     text not null default '',
  attended     boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists events_household_idx on public.events (household_id, starts_at);
alter table public.events enable row level security;

drop policy if exists "insiders read events" on public.events;
create policy "insiders read events" on public.events
  for select to authenticated using (household_id = public.my_household() and public.is_insider());
drop policy if exists "insiders add events" on public.events;
create policy "insiders add events" on public.events
  for insert to authenticated with check (household_id = public.my_household() and public.is_insider());
drop policy if exists "appa marks attended" on public.events;
create policy "appa marks attended" on public.events
  for update to authenticated using (household_id = public.my_household() and public.my_role() = 'appa');

-- ---------------------------------------------------------------- TNSTC retirees circle

create table if not exists public.circles (
  id         uuid primary key default gen_random_uuid(),
  join_code  text not null unique,
  name       text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.circle_members (
  circle_id      uuid not null references public.circles (id) on delete cascade,
  user_id        uuid not null references auth.users (id) on delete cascade,
  display_name   text not null,
  birthday_month int check (birthday_month between 1 and 12),
  birthday_day   int check (birthday_day between 1 and 31),
  joined_at      timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create table if not exists public.circle_answers (
  id          uuid primary key default gen_random_uuid(),
  circle_id   uuid not null references public.circles (id) on delete cascade,
  week        text not null,
  author_id   uuid not null default auth.uid(),
  author_name text not null,
  audio_path  text not null,
  created_at  timestamptz not null default now()
);
create index if not exists circle_answers_idx on public.circle_answers (circle_id, created_at desc);

create or replace function public.in_circle(p_circle uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.circle_members where circle_id = p_circle and user_id = auth.uid());
$$;
grant execute on function public.in_circle(uuid) to authenticated;

alter table public.circles        enable row level security;
alter table public.circle_members enable row level security;
alter table public.circle_answers enable row level security;

drop policy if exists "members see circle" on public.circles;
create policy "members see circle" on public.circles
  for select to authenticated using (public.in_circle(id));
drop policy if exists "members see members" on public.circle_members;
create policy "members see members" on public.circle_members
  for select to authenticated using (public.in_circle(circle_id));
drop policy if exists "member edits self" on public.circle_members;
create policy "member edits self" on public.circle_members
  for update to authenticated using (user_id = auth.uid());
drop policy if exists "members read answers" on public.circle_answers;
create policy "members read answers" on public.circle_answers
  for select to authenticated using (public.in_circle(circle_id));
drop policy if exists "members answer" on public.circle_answers;
create policy "members answer" on public.circle_answers
  for insert to authenticated with check (public.in_circle(circle_id) and author_id = auth.uid());
drop policy if exists "author deletes own answer" on public.circle_answers;
create policy "author deletes own answer" on public.circle_answers
  for delete to authenticated using (author_id = auth.uid());

create or replace function public.create_circle(p_name text, p_display_name text)
returns table (circle_id uuid, join_code text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare v_code text; v_id uuid; v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  loop
    v_code := 'C';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.circles where circles.join_code = v_code);
  end loop;
  insert into public.circles (join_code, name) values (v_code, coalesce(p_name, '')) returning id into v_id;
  insert into public.circle_members (circle_id, user_id, display_name) values (v_id, auth.uid(), coalesce(p_display_name, ''));
  return query select v_id, v_code;
end;
$$;

-- Join with either a help code (H...) or a circle code (C...).
create or replace function public.join_by_code(p_code text, p_display_name text)
returns json language plpgsql security definer set search_path = public as $$
declare v_code text := upper(trim(p_code)); v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select id into v_id from public.circles where join_code = v_code;
  if v_id is not null then
    insert into public.circle_members (circle_id, user_id, display_name)
      values (v_id, auth.uid(), coalesce(p_display_name, ''))
      on conflict (circle_id, user_id) do update set display_name = excluded.display_name;
    return json_build_object('kind', 'circle', 'id', v_id);
  end if;
  select id into v_id from public.households where help_code = v_code;
  if v_id is not null then
    -- Never downgrade or move an existing family member.
    if exists (select 1 from public.members where user_id = auth.uid()) then
      raise exception 'this phone is already in a household';
    end if;
    insert into public.members (user_id, household_id, role, display_name)
      values (auth.uid(), v_id, 'guest', coalesce(p_display_name, ''));
    return json_build_object('kind', 'help', 'id', v_id);
  end if;
  raise exception 'unknown code';
end;
$$;

grant execute on function public.help_code(), public.create_circle(text, text), public.join_by_code(text, text) to authenticated;

insert into storage.buckets (id, name, public) values ('circle', 'circle', false) on conflict (id) do nothing;

drop policy if exists "circle voice read" on storage.objects;
create policy "circle voice read" on storage.objects
  for select to authenticated
  using (bucket_id = 'circle' and public.in_circle(((storage.foldername(name))[1])::uuid));
drop policy if exists "circle voice write" on storage.objects;
create policy "circle voice write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'circle' and public.in_circle(((storage.foldername(name))[1])::uuid));
