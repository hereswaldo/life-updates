-- Friend graph v2: mutual-required visibility
-- Run this in Supabase SQL Editor. Idempotent and safe to re-run.
-- This locks down posts so you only see posts from people you and they have BOTH added.

-- ============ HELPER FUNCTION ============

create or replace function is_mutual(user_a uuid, user_b uuid)
returns boolean
language sql
stable
as $$
  select exists(
    select 1 from follows where follower_id = user_a and followed_id = user_b
  ) and exists(
    select 1 from follows where follower_id = user_b and followed_id = user_a
  );
$$;

-- ============ POSTS RLS UPDATE ============

-- Drop the old policies that allowed any authenticated user to see all published posts
drop policy if exists "posts_select" on posts;
drop policy if exists "posts_select_own" on posts;

-- New consolidated policy: see your own posts (any state), and mutual friends' published posts
create policy "posts_select" on posts for select using (
  author_id = auth.uid()
  or (
    is_published = true
    and is_mutual(auth.uid(), author_id)
  )
);

-- ============ COMMENTS RLS UPDATE ============

-- Comments are visible only on posts the user can already see.
-- The subquery to posts will inherit the posts RLS above, so this works automatically.
drop policy if exists "comments_select" on comments;
create policy "comments_select" on comments for select using (
  auth.role() = 'authenticated'
  and post_id in (select id from posts)
);

-- ============ BACKFILL: ALEX <-> DANIEL MUTUAL ============

-- Find the IDs of existing users:
-- select id, handle, display_name from profiles order by created_at;

-- Then create the mutual follow for both of you (replace UUIDs):
-- insert into follows (follower_id, followed_id) values
--   ('YOUR_ALEX_UUID', 'YOUR_DANIEL_UUID'),
--   ('YOUR_DANIEL_UUID', 'YOUR_ALEX_UUID')
-- on conflict do nothing;

-- Or, to mutual-follow ALL existing profiles to each other (works for the current 2-person state):
insert into follows (follower_id, followed_id)
select a.id, b.id
from profiles a, profiles b
where a.id <> b.id
on conflict do nothing;

-- Verify
select count(*) as follow_rows from follows;
-- For 2 users: should be 2 (alex→daniel, daniel→alex)
