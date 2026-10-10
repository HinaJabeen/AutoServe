-- ============================================
-- ENABLE RLS ON ALL TABLES
-- ============================================
alter table dealerships enable row level security;
alter table users enable row level security;
alter table vehicles enable row level security;
alter table vehicle_images enable row level security;
alter table leads enable row level security;
alter table notifications enable row level security;

-- ============================================
-- DEALERSHIPS POLICIES
-- ============================================

-- Dealer owners can view and update their own dealership
create policy "dealer_owners_view_own_dealership"
on dealerships for select to authenticated
using (
  id in (select dealership_id from users where id = auth.uid())
);

create policy "dealer_owners_update_own_dealership"
on dealerships for update to authenticated
using (
  id in (
    select dealership_id from users 
    where id = auth.uid() and role = 'dealer_owner'
  )
);

-- Super admins see everything
create policy "super_admin_full_access_dealerships"
on dealerships for all to authenticated
using (
  auth.uid() in (select id from users where role = 'super_admin')
);

-- Public can view approved dealerships (for displaying dealer name on listings)
create policy "public_view_approved_dealerships"
on dealerships for select to anon
using (status = 'approved');

-- ============================================
-- USERS POLICIES
-- ============================================

-- Users can view their own profile
create policy "users_view_own_profile"
on users for select to authenticated
using (id = auth.uid());

-- Users can update their own profile
create policy "users_update_own_profile"
on users for update to authenticated
using (id = auth.uid());

-- Dealer owners can view staff in their own dealership
create policy "dealer_owners_view_staff"
on users for select to authenticated
using (
  dealership_id in (
    select dealership_id from users 
    where id = auth.uid() and role = 'dealer_owner'
  )
);

-- Super admins see all users
create policy "super_admin_full_access_users"
on users for all to authenticated
using (
  auth.uid() in (select id from users where role = 'super_admin')
);

-- ============================================
-- VEHICLES POLICIES
-- ============================================

-- Dealers manage their own vehicles (full CRUD)
create policy "dealers_manage_own_vehicles"
on vehicles for all to authenticated
using (
  dealership_id in (
    select dealership_id from users where id = auth.uid()
  )
);

-- Authenticated consumers view available vehicles
create policy "consumers_view_available_vehicles"
on vehicles for select to authenticated
using (status = 'available');

-- Anonymous/public users can browse available vehicles (no login wall for browsing)
create policy "public_view_available_vehicles"
on vehicles for select to anon
using (status = 'available');

-- ============================================
-- VEHICLE IMAGES POLICIES
-- ============================================

create policy "dealers_manage_own_vehicle_images"
on vehicle_images for all to authenticated
using (
  vehicle_id in (
    select v.id from vehicles v
    join users u on u.dealership_id = v.dealership_id
    where u.id = auth.uid()
  )
);

create policy "public_view_vehicle_images"
on vehicle_images for select to anon
using (true);

create policy "authenticated_view_vehicle_images"
on vehicle_images for select to authenticated
using (true);

-- ============================================
-- LEADS POLICIES
-- ============================================

-- Dealers see and manage leads for their own dealership
create policy "dealers_manage_own_leads"
on leads for all to authenticated
using (
  dealership_id in (
    select dealership_id from users where id = auth.uid()
  )
);

-- Consumers can create leads (insert only, cannot view others' leads)
create policy "consumers_create_leads"
on leads for insert to authenticated
with check (
  auth.uid() in (select id from users where role = 'consumer')
);

-- Consumers can view their own submitted leads
create policy "consumers_view_own_leads"
on leads for select to authenticated
using (consumer_id = auth.uid());

-- ============================================
-- NOTIFICATIONS POLICIES
-- ============================================

create policy "users_view_own_notifications"
on notifications for select to authenticated
using (user_id = auth.uid());

create policy "users_update_own_notifications"
on notifications for update to authenticated
using (user_id = auth.uid());

-- System (via service role / security definer functions) creates notifications
-- No public insert policy needed since these are server-generated