-- Friend graph v3: server-side accept_invite + search-friendly indexes
-- Run in Supabase SQL editor. Idempotent.

-- ============ ACCEPT_INVITE RPC ============
-- The client cannot insert a follow row where it is not the follower (RLS).
-- So when a new user comes in via an invite link, we cannot create the
-- "inviter → invitee" row from the invitee's session. This function runs
-- with SECURITY DEFINER so it can write both rows atomically.

create or replace function accept_invite(inviter_uuid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (select 1 from profiles where id = inviter_uuid) then
    raise exception 'Inviter not found';
  end if;
  if current_user_id = inviter_uuid then
    return; -- no-op: can't invite yourself
  end if;
  insert into follows (follower_id, followed_id) values
    (current_user_id, inviter_uuid),
    (inviter_uuid, current_user_id)
  on conflict do nothing;
end;
$$;

revoke all on function accept_invite(uuid) from public;
grant execute on function accept_invite(uuid) to authenticated;

-- ============ SEARCH INDEXES ============
-- Speed up the handle + display_name ilike searches used by the in-app
-- find-friends UI. trigram indexes make %term% queries fast.

create extension if not exists pg_trgm;

create index if not exists profiles_handle_trgm_idx on profiles using gin (handle gin_trgm_ops);
create index if not exists profiles_display_name_trgm_idx on profiles using gin (display_name gin_trgm_ops);

-- ============ BACKFILL EXISTING INVITE GAPS ============
-- If Elisa (or anyone else) signed up via an invite link before this fix,
-- their follow record never made it in. List who is signed up but has zero
-- follow rows so you can decide manually:

-- select p.id, p.handle, p.display_name
-- from profiles p
-- where not exists (select 1 from follows f where f.follower_id = p.id)
--   and not exists (select 1 from follows f where f.followed_id = p.id);
