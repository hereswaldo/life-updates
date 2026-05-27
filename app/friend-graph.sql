-- Friend graph bootstrap for Life Update:
-- Run this AFTER all 6 friends have signed up.
-- This creates a mutual-follow relationship between every pair of users.

-- Step 1: confirm the right people are signed up
select id, handle, display_name, city from profiles order by created_at;

-- Step 2: wire mutual follows for everyone (if you trust the list above)
-- This is "everyone follows everyone" — perfect for a 6-person friend group.
-- Idempotent: safe to re-run, won't create duplicates.

insert into follows (follower_id, followed_id)
select a.id, b.id
from profiles a, profiles b
where a.id <> b.id
on conflict do nothing;

-- Step 3: verify
select count(*) as follow_count from follows;
-- For 6 users: should be 30 (each of 6 follows the other 5)
