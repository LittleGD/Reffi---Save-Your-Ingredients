-- Self-service account deletion. No user ID is accepted from the caller.
-- Apply after 0002_analytics.sql as the database owner.
begin;

-- New rows must reference a live account; FK locking also closes upload/delete races.
-- NOT VALID preserves legacy orphan rows for a separate reviewed retention migration.
alter table public.analytics_events drop constraint if exists analytics_events_user_fkey;
alter table public.analytics_events add constraint analytics_events_user_fkey
  foreign key (user_id) references auth.users(id) on delete cascade not valid;

-- A deleted account's still-valid JWT cannot create more events after deletion.
create or replace function public.has_active_account()
returns boolean
language sql stable security definer
set search_path = ''
as $$ select exists(select 1 from auth.users where id = auth.uid()); $$;
revoke all on function public.has_active_account() from public, anon;
grant execute on function public.has_active_account() to authenticated;

drop policy if exists analytics_events_insert_own on public.analytics_events;
create policy analytics_events_insert_own on public.analytics_events
for insert to authenticated
with check (user_id = auth.uid() and public.has_active_account());

create or replace function public.delete_own_account()
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null or auth.role() <> 'authenticated' then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  -- Serialize against concurrent deletion and identity changes.
  perform 1 from auth.users where id = caller for update;
  if not found then
    return; -- retry after a response was lost
  end if;
  -- Apple must stay disabled until server-side token revocation is configured.
  if exists(select 1 from auth.identities where user_id = caller and provider = 'apple') then
    raise exception 'Apple token revocation is required before deletion';
  end if;
  delete from public.analytics_events where user_id = caller;
  delete from public.ai_usage where user_id = caller;
  delete from auth.users where id = caller;
end;
$$;
revoke all on function public.delete_own_account() from public, anon;
grant execute on function public.delete_own_account() to authenticated;
comment on function public.delete_own_account() is
  'Permanently deletes only the authenticated caller and their app data in one transaction.';
commit;
