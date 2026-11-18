-- Mobily content calendar schema
create table if not exists public.posts (
  id text primary key default gen_random_uuid()::text,
  date text not null,
  time text not null default '',
  caption text not null default '',
  media jsonb not null default '[]'::jsonb,
  design text not null default '',
  animation text not null default '',
  links jsonb not null default '{}'::jsonb,
  landing text not null default '',
  note text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.posts enable row level security;
drop policy if exists "team can read" on public.posts;
drop policy if exists "team can write" on public.posts;
create policy "team can read" on public.posts for select to authenticated using (true);
create policy "team can write" on public.posts for all to authenticated using (true) with check (true);

insert into storage.buckets (id, name, public) values ('media', 'media', false) on conflict (id) do nothing;
drop policy if exists "team media read" on storage.objects;
drop policy if exists "team media write" on storage.objects;
create policy "team media read" on storage.objects for select to authenticated using (bucket_id = 'media');
create policy "team media write" on storage.objects for all to authenticated using (bucket_id = 'media') with check (bucket_id = 'media');

do $$ begin
  alter publication supabase_realtime add table public.posts;
exception when duplicate_object then null; end $$;
