-- Post name («اسم المنشور»), 19 Nov 2026
-- Until this runs, the site keeps each post's name in links._title.
-- Run once in the Supabase SQL editor: it adds the column and moves the names into it.
alter table public.posts add column if not exists title text not null default '';

update public.posts
set title = coalesce(nullif(trim(links->>'_title'), ''), title),
    links = links - '_title'
where links ? '_title';

-- activity labels use the post name when there is one
create or replace function public.post_label(p public.posts) returns text language sql immutable as $$
  select coalesce(
    nullif(left(trim(p.title), 40), ''),
    nullif(left(trim(split_part(trim(p.caption), E'\n', 1)), 40), ''),
    'بوست ' || p.date || coalesce(nullif(' ' || p.time, ' '), ''));
$$;
