-- activity log: every change to posts is recorded by a trigger (whoever makes it, from any client)
create table if not exists public.activity (
  id bigserial primary key,
  at timestamptz not null default now(),
  actor text not null default 'system',
  action text not null,            -- create | update | move | delete
  post_id text,
  label text not null default '',
  details jsonb not null default '{}'::jsonb
);
create index if not exists activity_at_idx on public.activity (at desc);
alter table public.activity enable row level security;
drop policy if exists "team reads activity" on public.activity;
create policy "team reads activity" on public.activity for select to authenticated using (true);

create or replace function public.post_label(p public.posts) returns text language sql immutable as $$
  select coalesce(nullif(left(trim(split_part(trim(p.caption), E'\n', 1)), 40), ''), 'بوست ' || p.date || coalesce(nullif(' ' || p.time, ' '), ''));
$$;

create or replace function public.log_post_activity() returns trigger
language plpgsql security definer set search_path = public, auth as $$
declare
  who text;
  act text;
  lbl text;
  det jsonb := '{}'::jsonb;
  ch text[] := '{}';
begin
  select email into who from auth.users where id = auth.uid();
  who := coalesce(who, 'system');
  if tg_op = 'INSERT' then
    act := 'create'; lbl := post_label(new);
    det := jsonb_build_object('date', new.date, 'time', new.time);
  elsif tg_op = 'DELETE' then
    act := 'delete'; lbl := post_label(old);
    det := jsonb_build_object('date', old.date, 'time', old.time);
  else
    if new.date is distinct from old.date then ch := ch || 'date'; end if;
    if new.time is distinct from old.time then ch := ch || 'time'; end if;
    if new.caption is distinct from old.caption then ch := ch || 'caption'; end if;
    if new.media is distinct from old.media then ch := ch || 'media'; end if;
    if new.design is distinct from old.design then ch := ch || 'design'; end if;
    if new.animation is distinct from old.animation then ch := ch || 'animation'; end if;
    if new.links is distinct from old.links then ch := ch || 'links'; end if;
    if new.landing is distinct from old.landing then ch := ch || 'landing'; end if;
    if new.note is distinct from old.note then ch := ch || 'note'; end if;
    if coalesce(array_length(ch, 1), 0) = 0 then return new; end if;
    act := case when ch = array['date'] then 'move' else 'update' end;
    lbl := post_label(new);
    det := jsonb_build_object(
      'fields', to_jsonb(ch),
      'from', old.date, 'to', new.date,
      'old_time', old.time, 'new_time', new.time,
      'media_delta', jsonb_array_length(new.media) - jsonb_array_length(old.media),
      'links', (select count(*) from jsonb_object_keys(new.links)));
  end if;
  insert into public.activity (actor, action, post_id, label, details)
  values (who, act, coalesce(new.id, old.id), lbl, det);
  delete from public.activity where at < now() - interval '90 days';
  return coalesce(new, old);
end $$;

drop trigger if exists posts_activity on public.posts;
create trigger posts_activity after insert or update or delete on public.posts
for each row execute function public.log_post_activity();

do $$ begin
  alter publication supabase_realtime add table public.activity;
exception when duplicate_object then null; end $$;

select 'ok' as status;
