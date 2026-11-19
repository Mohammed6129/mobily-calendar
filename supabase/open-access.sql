-- No sign-in: the site is open to anyone with the link (Mohammed's decision, 19 Nov 2026).
-- Who made a change is taken from the x-actor header the site sends (chosen once per browser).
drop policy if exists "team can read" on public.posts;
drop policy if exists "team can write" on public.posts;
drop policy if exists "open posts" on public.posts;
create policy "open posts" on public.posts for all to anon, authenticated using (true) with check (true);

drop policy if exists "team dictionary" on public.dictionary;
drop policy if exists "open dictionary" on public.dictionary;
create policy "open dictionary" on public.dictionary for all to anon, authenticated using (true) with check (true);

drop policy if exists "team reads activity" on public.activity;
drop policy if exists "open activity read" on public.activity;
create policy "open activity read" on public.activity for select to anon, authenticated using (true);

drop policy if exists "team media read" on storage.objects;
drop policy if exists "team media write" on storage.objects;
drop policy if exists "open media" on storage.objects;
create policy "open media" on storage.objects for all to anon, authenticated using (bucket_id = 'media') with check (bucket_id = 'media');

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

select 'ok' as status;
