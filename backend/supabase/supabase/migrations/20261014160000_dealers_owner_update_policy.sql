-- ============================================
-- DEALERS — let owners update their own dealership
-- ============================================
-- Saving Dealer Settings as an owner updated ZERO rows on the live project:
-- the row is readable (the form loads), but the UPDATE policy didn't match.
-- RLS filters non-matching rows silently instead of raising an error.
--
-- This (re)creates the owner update policy with the same rule the dashboard
-- uses to decide who is an owner (auth_provider.dart _resolveRole):
--   * role contains "owner" — matches 'owner', 'dealer_owner', 'Dealer Owner'
--   * status is anything but 'deactivated' — a NULL status counts as active
-- Permissive policies are OR-ed together, so this works alongside any other
-- update policy already on the live table, whatever it is named.
-- Idempotent: safe to re-run.

drop policy if exists "owners_update_own_dealer" on public.dealers;

create policy "owners_update_own_dealer"
on public.dealers for update to authenticated
using (
  id in (
    select dealer_id from public.dealer_staff
    where user_id = auth.uid()
      and lower(role) like '%owner%'
      and coalesce(status, 'active') <> 'deactivated'
  )
)
with check (
  id in (
    select dealer_id from public.dealer_staff
    where user_id = auth.uid()
      and lower(role) like '%owner%'
      and coalesce(status, 'active') <> 'deactivated'
  )
);
