-- ============================================
-- CUSTOMER PROFILES — consumer identity for apps/customer
-- ============================================
-- apps/customer now requires sign-in (Supabase Auth email/password), so the
-- schema needs somewhere to keep a consumer's name/phone and a role the app
-- can route on. This supersedes the "no consumer-identity table / no signup
-- trigger" notes in 20260630062836_rls_policies.sql and
-- 20260630063131_auth_triggers_and_functions.sql.
--
-- `profiles` is NOT a replacement for dealer_staff/admin_users — those stay
-- the source of truth for tenant scope and every existing RLS policy keeps
-- deriving access from them. `profiles.role` is a read-only mirror of them
-- ('dealer' if a dealer_staff row exists, 'admin' if an admin_users row
-- exists, otherwise 'customer'), kept in sync by the triggers below. No RLS
-- policy anywhere trusts it; the customer app only uses it to turn staff
-- accounts away at login.

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default ''
    check (char_length(full_name) <= 120),
  phone text
    check (phone is null or char_length(phone) <= 32),
  role text not null default 'customer'
    check (role in ('customer', 'dealer', 'admin')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create trigger set_updated_at_profiles
  before update on profiles
  for each row execute function update_updated_at_column();

-- ============================================
-- RLS + GRANTS
-- ============================================
alter table profiles enable row level security;

-- A signed-in user can read their own profile row, and only that row.
create policy "users_view_own_profile"
on profiles for select to authenticated
using (id = auth.uid());

-- A signed-in user can edit their own row...
create policy "users_update_own_profile"
on profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- ...but only the name/phone columns. RLS is row-level, so it can't stop a
-- user rewriting `role` on their own row; column grants can. Supabase grants
-- ALL on new public tables to anon/authenticated by default, hence the
-- explicit revoke first. No insert/delete for clients at all: rows are
-- created by handle_new_user() and removed by the auth.users cascade.
revoke all on profiles from anon, authenticated;
grant select on profiles to authenticated;
grant update (full_name, phone) on profiles to authenticated;

-- ============================================
-- CREATE A PROFILE ROW ON SIGNUP
-- ============================================
-- raw_user_meta_data is whatever the client passed to auth.signUp(data: ...),
-- i.e. untrusted input. Only full_name/phone are read from it (truncated to
-- fit the checks above, so a hostile payload can't make this insert fail and
-- block signups); role is always 'customer' and never taken from metadata.
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(left(trim(new.raw_user_meta_data ->> 'full_name'), 120), ''),
    nullif(left(trim(new.raw_user_meta_data ->> 'phone'), 32), ''),
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================
-- KEEP profiles.role IN SYNC WITH dealer_staff / admin_users
-- ============================================
-- Staff accounts are created in auth.users first (so handle_new_user() gives
-- them a 'customer' profile) and only then linked into dealer_staff /
-- admin_users. This recomputes the mirror whenever that link is added or
-- removed. TG_ARGV[0] names the column on the triggering table that holds
-- the auth user id.
create or replace function sync_profile_role()
returns trigger as $$
declare
  affected jsonb;
  target_user uuid;
begin
  if tg_op = 'DELETE' then
    affected := to_jsonb(old);
  else
    affected := to_jsonb(new);
  end if;
  target_user := (affected ->> tg_argv[0])::uuid;

  update profiles
  set role = case
    when exists (select 1 from admin_users where id = target_user) then 'admin'
    when exists (select 1 from dealer_staff where user_id = target_user) then 'dealer'
    else 'customer'
  end
  where id = target_user;

  return null;
end;
$$ language plpgsql security definer set search_path = public;

create trigger sync_profile_role_on_dealer_staff
  after insert or delete on dealer_staff
  for each row execute function sync_profile_role('user_id');

create trigger sync_profile_role_on_admin_users
  after insert or delete on admin_users
  for each row execute function sync_profile_role('id');

-- ============================================
-- BACKFILL — accounts that existed before this migration
-- ============================================
insert into profiles (id, full_name, phone, role)
select
  u.id,
  coalesce(
    left(a.full_name, 120),
    left(s.full_name, 120),
    left(trim(u.raw_user_meta_data ->> 'full_name'), 120),
    ''
  ),
  nullif(left(trim(u.raw_user_meta_data ->> 'phone'), 32), ''),
  case
    when a.id is not null then 'admin'
    when s.user_id is not null then 'dealer'
    else 'customer'
  end
from auth.users u
left join dealer_staff s on s.user_id = u.id
left join admin_users a on a.id = u.id
on conflict (id) do nothing;

-- ============================================
-- DEALERS — let signed-in customers see approved dealerships
-- ============================================
-- "public_view_approved_dealers" only covers the `anon` role. Now that the
-- customer app's requests carry a user JWT they run as `authenticated`, and
-- without this the vehicle detail screen's `dealers(*)` join comes back
-- empty for every signed-in customer. Same rows, same predicate as the
-- existing anon policy — nothing becomes visible that wasn't already public.
create policy "authenticated_view_approved_dealers"
on dealers for select to authenticated
using (status = 'approved');
