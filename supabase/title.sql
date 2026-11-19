-- Post name («اسم المنشور») + fix for editing existing posts, 19 Nov 2026
-- Run the whole file once in the Supabase SQL editor (project mobily-calendar).
-- Until it runs, the site keeps each post's name in links._title.

begin;

-- 1) the new column
alter table public.posts add column if not exists title text not null default '';

-- 2) FIX: every edit to an existing post failed with
--    "malformed array literal" because `ch || 'links'` read the word as an array.
--    array_append(ch, '...'::text) adds it as one item. Also tracks the new title field.
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
  if who is null then
    begin
      who := nullif(lower(current_setting('request.headers', true)::json->>'x-actor'), '');
    exception when others then who := null;
    end;
  end if;
  who := coalesce(who, 'system');
  if tg_op = 'INSERT' then
    act := 'create'; lbl := post_label(new);
    det := jsonb_build_object('date', new.date, 'time', new.time);
  elsif tg_op = 'DELETE' then
    act := 'delete'; lbl := post_label(old);
    det := jsonb_build_object('date', old.date, 'time', old.time);
  else
    if new.date is distinct from old.date then ch := array_append(ch, 'date'::text); end if;
    if new.time is distinct from old.time then ch := array_append(ch, 'time'::text); end if;
    if new.caption is distinct from old.caption then ch := array_append(ch, 'caption'::text); end if;
    if new.media is distinct from old.media then ch := array_append(ch, 'media'::text); end if;
    if new.design is distinct from old.design then ch := array_append(ch, 'design'::text); end if;
    if new.animation is distinct from old.animation then ch := array_append(ch, 'animation'::text); end if;
    if new.links is distinct from old.links then ch := array_append(ch, 'links'::text); end if;
    if new.landing is distinct from old.landing then ch := array_append(ch, 'landing'::text); end if;
    if new.note is distinct from old.note then ch := array_append(ch, 'note'::text); end if;
    if new.title is distinct from old.title then ch := array_append(ch, 'title'::text); end if;
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


-- 3) activity labels use the post name when there is one
create or replace function public.post_label(p public.posts) returns text language sql immutable as $$
  select coalesce(
    nullif(left(trim(p.title), 40), ''),
    nullif(left(trim(split_part(trim(p.caption), E'\n', 1)), 40), ''),
    'بوست ' || p.date || coalesce(nullif(' ' || p.time, ' '), ''));
$$;


-- 4) names already kept in links._title move into the column
update public.posts
set title = coalesce(nullif(trim(links->>'_title'), ''), title),
    links = links - '_title'
where links ? '_title';


-- 5) names for the posts that were already on the calendar (only where still empty)
update public.posts p set title = v.name
from (values
  ('7fc0c27d', 'باقة 100GB مسبق الدفع'),
  ('72645036', 'AirPods 5'),
  ('b3f75353', 'AirPods 5'),
  ('621695b0', 'AirPods 5'),
  ('52a41e58', 'باقة 20GB مسبق الدفع'),
  ('22fef107', 'موبايلي هوم 5G'),
  ('3a5a0cd3', 'هوم فايبر 300 ميجا'),
  ('a8199023', 'الباقة الأسبوعية بلس'),
  ('54e52732', 'باقة 50GB مسبق الدفع'),
  ('4ec7ff33', 'HUAWEI nova 16s'),
  ('5a84333f', 'iPhone 18 Pro'),
  ('13859bdd', 'Galaxy S26'),
  ('9a99dbf2', 'باقة شامل ماكس'),
  ('4eb4ba1e', 'iPad mini'),
  ('e9bfc385', 'باقة مسبق الدفع 110'),
  ('3c536175', 'Apple Watch Series 12'),
  ('2e77d564', 'باقة شامل ستارت'),
  ('c1641bce', 'هوم فايبر 300 ميجا'),
  ('e0743074', 'iPhone Duo'),
  ('ffca885c', 'Apple Music مع شامل'),
  ('501af68d', 'iCloud+ مع شامل'),
  ('fb7319df', 'باقة 10GB مسبق الدفع'),
  ('3cf56a6c', 'Galaxy Z Fold8 و Flip8'),
  ('810be8e9', 'موبايلي هوم 5G')
) as v(prefix, name)
where p.id like v.prefix || '%' and p.title = '';

commit;

select 'ok' as status;
