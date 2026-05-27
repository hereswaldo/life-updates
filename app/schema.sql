-- Life Update: schema for Supabase
-- Safe to re-run. All statements are idempotent.
-- Paste into Supabase SQL Editor → New Query → Run.

-- ============ TABLES ============

create table if not exists profiles (
  id uuid primary key references auth.users on delete cascade,
  handle text unique not null,
  display_name text not null,
  full_name text,
  city text,
  avatar_url text,
  initials text,
  created_at timestamptz default now()
);

create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  issue_month text not null, -- 'YYYY-MM' e.g. '2026-05'
  title text,
  sticker_text text,
  sticker_color text,
  sections jsonb default '[]'::jsonb,
  photos jsonb default '[]'::jsonb,
  life_update text,
  is_published boolean default false,
  published_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (author_id, issue_month)
);

create table if not exists comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);

create table if not exists follows (
  follower_id uuid not null references profiles(id) on delete cascade,
  followed_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, followed_id)
);

-- ============ INDEXES ============

create index if not exists posts_issue_month_idx on posts (issue_month, published_at desc);
create index if not exists posts_author_idx on posts (author_id);
create index if not exists comments_post_idx on comments (post_id, created_at);
create index if not exists follows_follower_idx on follows (follower_id);

-- ============ ROW-LEVEL SECURITY ============

alter table profiles enable row level security;
alter table posts enable row level security;
alter table comments enable row level security;
alter table follows enable row level security;

-- profiles
drop policy if exists "profiles_select" on profiles;
drop policy if exists "profiles_insert" on profiles;
drop policy if exists "profiles_update" on profiles;
create policy "profiles_select" on profiles for select using (auth.role() = 'authenticated');
create policy "profiles_insert" on profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on profiles for update using (auth.uid() = id);

-- posts
drop policy if exists "posts_select" on posts;
drop policy if exists "posts_select_own" on posts;
drop policy if exists "posts_insert" on posts;
drop policy if exists "posts_update" on posts;
drop policy if exists "posts_delete" on posts;
create policy "posts_select" on posts for select using (auth.role() = 'authenticated' and is_published = true);
create policy "posts_select_own" on posts for select using (auth.uid() = author_id);
create policy "posts_insert" on posts for insert with check (auth.uid() = author_id);
create policy "posts_update" on posts for update using (auth.uid() = author_id);
create policy "posts_delete" on posts for delete using (auth.uid() = author_id);

-- comments
drop policy if exists "comments_select" on comments;
drop policy if exists "comments_insert" on comments;
drop policy if exists "comments_delete" on comments;
create policy "comments_select" on comments for select using (auth.role() = 'authenticated');
create policy "comments_insert" on comments for insert with check (auth.uid() = author_id);
create policy "comments_delete" on comments for delete using (auth.uid() = author_id);

-- follows
drop policy if exists "follows_select" on follows;
drop policy if exists "follows_insert" on follows;
drop policy if exists "follows_delete" on follows;
create policy "follows_select" on follows for select using (auth.role() = 'authenticated');
create policy "follows_insert" on follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on follows for delete using (auth.uid() = follower_id);

-- ============ STORAGE ============

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "photos_select" on storage.objects;
drop policy if exists "photos_insert" on storage.objects;
drop policy if exists "photos_update" on storage.objects;
drop policy if exists "photos_delete" on storage.objects;
create policy "photos_select" on storage.objects for select using (bucket_id = 'photos');
create policy "photos_insert" on storage.objects for insert with check (
  bucket_id = 'photos' and auth.role() = 'authenticated'
);
create policy "photos_update" on storage.objects for update using (
  bucket_id = 'photos' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "photos_delete" on storage.objects for delete using (
  bucket_id = 'photos' and auth.uid()::text = (storage.foldername(name))[1]
);
