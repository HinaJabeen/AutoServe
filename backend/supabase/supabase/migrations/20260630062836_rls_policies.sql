-- ============================================
-- RLS POLICIES — reconciled against live schema (dealers/dealer_staff/cars/...)
-- ============================================
-- Supersedes the earlier version of this migration, written against the
-- outdated vehicles/users schema. Tenant scope is now derived from
-- dealer_staff (active staff only), never from a client-supplied dealer_id.

-- ============================================
-- ENABLE RLS ON ALL TABLES
-- ============================================
alter table dealers enable row level security;
alter table dealer_staff enable row level security;
alter table admin_users enable row level security;
alter table cars enable row level security;
alter table car_photos enable row level security;
alter table car_audit_logs enable row level security;
alter table leads enable row level security;
alter table lead_activity enable row level security;
alter table notifications enable row level security;
alter table staff_invites enable row level security;
alter table admin_activity enable row level security;
alter table ai_usage_log enable row level security;

-- ============================================
-- DEALERS POLICIES
-- ============================================

-- Staff can view and update their own dealership
create policy "staff_view_own_dealer"
on dealers for select to authenticated
using (
  id in (
    select dealer_id from dealer_staff
    where user_id = auth.uid() and status = 'active'
  )
);

create policy "owners_update_own_dealer"
on dealers for update to authenticated
using (
  id in (
    select dealer_id from dealer_staff
    where user_id = auth.uid() and role = 'owner' and status = 'active'
  )
);

-- Super admins see everything
create policy "super_admin_full_access_dealers"
on dealers for all to authenticated
using (auth.uid() in (select id from admin_users));

-- Public can view approved dealerships (e.g. attribution on listings)
create policy "public_view_approved_dealers"
on dealers for select to anon
using (status = 'approved');

-- ============================================
-- DEALER STAFF POLICIES
-- ============================================

-- Staff can view their own row
create policy "staff_view_own_row"
on dealer_staff for select to authenticated
using (user_id = auth.uid());

-- Staff can update their own row (e.g. clearing requires_password_change,
-- updating full_name — see auth_provider.dart)
create policy "staff_update_own_row"
on dealer_staff for update to authenticated
using (user_id = auth.uid());

-- Dealer owners can view and manage staff within their own dealership
create policy "owners_manage_own_staff"
on dealer_staff for all to authenticated
using (
  dealer_id in (
    select dealer_id from dealer_staff
    where user_id = auth.uid() and role = 'owner' and status = 'active'
  )
);

create policy "super_admin_full_access_dealer_staff"
on dealer_staff for all to authenticated
using (auth.uid() in (select id from admin_users));

-- ============================================
-- ADMIN USERS POLICIES
-- ============================================

create policy "admin_view_own_row"
on admin_users for select to authenticated
using (id = auth.uid());

create policy "super_admin_manage_admin_users"
on admin_users for all to authenticated
using (auth.uid() in (select id from admin_users));

-- ============================================
-- CARS POLICIES
-- ============================================

-- Dealers manage their own inventory (full CRUD)
create policy "staff_manage_own_cars"
on cars for all to authenticated
using (
  dealer_id in (
    select dealer_id from dealer_staff
    where user_id = auth.uid() and status = 'active'
  )
);

-- Authenticated users can view public, available listings
create policy "authenticated_view_public_cars"
on cars for select to authenticated
using (is_public = true and status = 'available');

-- Anonymous/public users can browse public listings (no login wall)
create policy "public_view_public_cars"
on cars for select to anon
using (is_public = true and status = 'available');

create policy "super_admin_full_access_cars"
on cars for all to authenticated
using (auth.uid() in (select id from admin_users));

-- ============================================
-- CAR PHOTOS POLICIES
-- ============================================

create policy "staff_manage_own_car_photos"
on car_photos for all to authenticated
using (
  car_id in (
    select c.id from cars c
    join dealer_staff s on s.dealer_id = c.dealer_id
    where s.user_id = auth.uid() and s.status = 'active'
  )
);

create policy "public_view_car_photos"
on car_photos for select to anon
using (
  car_id in (select id from cars where is_public = true and status = 'available')
);

create policy "authenticated_view_car_photos"
on car_photos for select to authenticated
using (true);

-- ============================================
-- CAR AUDIT LOGS POLICIES
-- ============================================

-- Audit trail is staff-readable only; writes happen via triggers/service role.
create policy "staff_view_own_car_audit_logs"
on car_audit_logs for select to authenticated
using (
  car_id in (
    select c.id from cars c
    join dealer_staff s on s.dealer_id = c.dealer_id
    where s.user_id = auth.uid() and s.status = 'active'
  )
);

create policy "super_admin_full_access_car_audit_logs"
on car_audit_logs for all to authenticated
using (auth.uid() in (select id from admin_users));

-- ============================================
-- LEADS POLICIES
-- ============================================

-- Dealers see and manage leads for their own dealership
create policy "staff_manage_own_leads"
on leads for all to authenticated
using (
  dealer_id in (
    select dealer_id from dealer_staff
    where user_id = auth.uid() and status = 'active'
  )
);

-- The public portal has no consumer auth table in this schema — lead
-- capture from the customer-facing app happens via anon insert only.
create policy "public_create_leads"
on leads for insert to anon
with check (true);

create policy "authenticated_create_leads"
on leads for insert to authenticated
with check (true);

create policy "super_admin_full_access_leads"
on leads for all to authenticated
using (auth.uid() in (select id from admin_users));

-- ============================================
-- LEAD ACTIVITY POLICIES
-- ============================================

create policy "staff_manage_own_lead_activity"
on lead_activity for all to authenticated
using (
  lead_id in (
    select l.id from leads l
    join dealer_staff s on s.dealer_id = l.dealer_id
    where s.user_id = auth.uid() and s.status = 'active'
  )
);

-- ============================================
-- NOTIFICATIONS POLICIES
-- ============================================

create policy "users_view_own_notifications"
on notifications for select to authenticated
using (user_id = auth.uid());

create policy "users_update_own_notifications"
on notifications for update to authenticated
using (user_id = auth.uid());

-- System (via security definer functions) creates notifications.
-- No direct insert policy needed since these are server-generated.

-- ============================================
-- STAFF INVITES POLICIES
-- ============================================

create policy "owners_manage_own_staff_invites"
on staff_invites for all to authenticated
using (
  dealer_id in (
    select dealer_id from dealer_staff
    where user_id = auth.uid() and role = 'owner' and status = 'active'
  )
);

-- ============================================
-- ADMIN ACTIVITY POLICIES
-- ============================================

create policy "super_admin_full_access_admin_activity"
on admin_activity for all to authenticated
using (auth.uid() in (select id from admin_users));

-- ============================================
-- AI USAGE LOG POLICIES
-- ============================================

create policy "staff_view_own_ai_usage_log"
on ai_usage_log for select to authenticated
using (
  dealer_id in (
    select dealer_id from dealer_staff
    where user_id = auth.uid() and status = 'active'
  )
);

create policy "super_admin_full_access_ai_usage_log"
on ai_usage_log for all to authenticated
using (auth.uid() in (select id from admin_users));
