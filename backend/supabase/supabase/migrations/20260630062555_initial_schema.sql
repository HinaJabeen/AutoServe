-- ============================================
-- AUTOSERVE SCHEMA — reconciled against live Supabase tables
-- ============================================
-- Supersedes the earlier version of this migration, which modeled a
-- `vehicles` + generic `users` schema that does not match production.
-- The live tables are: dealers, dealer_staff, cars, car_photos,
-- car_audit_logs, leads, lead_activity, notifications, staff_invites,
-- admin_users, admin_activity, ai_usage_log. See docs/architecture.md §4.

create extension if not exists "uuid-ossp";

-- ============================================
-- DEALERS (tenant dealership accounts)
-- ============================================
create table dealers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_name text not null,
  email text unique not null,
  phone text not null,
  city text not null,
  address text,
  logo_url text,
  status text default 'pending'
    check (status in ('pending', 'approved', 'suspended')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- DEALER STAFF (staff profiles linked to dealers and Supabase Auth)
-- ============================================
create table dealer_staff (
  id uuid primary key default gen_random_uuid(),
  dealer_id uuid not null references dealers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'staff'
    check (role in ('owner', 'staff')),
  status text not null default 'active'
    check (status in ('active', 'deactivated')),
  requires_password_change boolean not null default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id)
);

create index idx_dealer_staff_dealer on dealer_staff(dealer_id);

-- ============================================
-- ADMIN USERS (superadmin / platform-level access)
-- ============================================
create table admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null default 'super_admin'
    check (role in ('super_admin')),
  created_at timestamptz default now()
);

-- ============================================
-- CARS (inventory vehicles belonging to a dealership)
-- ============================================
create table cars (
  id uuid primary key default gen_random_uuid(),
  dealer_id uuid not null references dealers(id) on delete cascade,
  make text not null,
  model text not null,
  year integer not null check (year >= 1980 and year <= 2030),
  price numeric(12,2) not null check (price > 0),
  status text default 'available'
    check (status in ('available', 'reserved', 'sold', 'inactive')),
  mileage integer check (mileage >= 0),
  color text,
  transmission text check (transmission in ('manual', 'automatic')),
  fuel_type text check (fuel_type in
    ('petrol', 'diesel', 'hybrid', 'electric')),
  condition text check (condition in ('new', 'used', 'certified')),
  specs jsonb not null default '{}'::jsonb,
  purchase_price numeric(12,2),
  retail_price numeric(12,2),
  is_public boolean not null default true,
  features text[] not null default '{}'::text[],
  reconditioning_notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_cars_dealer on cars(dealer_id);
create index idx_cars_status on cars(status);
create index idx_cars_make_model on cars(make, model);

-- ============================================
-- CAR PHOTOS (storage URLs and metadata for vehicle images)
-- ============================================
create table car_photos (
  id uuid primary key default gen_random_uuid(),
  car_id uuid not null references cars(id) on delete cascade,
  storage_path text not null,
  is_primary boolean not null default false,
  display_order integer not null default 0,
  created_at timestamptz default now()
);

create index idx_car_photos_car on car_photos(car_id);

-- ============================================
-- CAR AUDIT LOGS (history/audit trail for inventory actions)
-- ============================================
create table car_audit_logs (
  id uuid primary key default gen_random_uuid(),
  car_id uuid not null references cars(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz default now()
);

create index idx_car_audit_logs_car on car_audit_logs(car_id);

-- ============================================
-- LEADS (CRM inquiries and sales pipeline leads)
-- ============================================
create table leads (
  id uuid primary key default gen_random_uuid(),
  dealer_id uuid not null references dealers(id) on delete cascade,
  car_id uuid references cars(id) on delete set null,
  customer_name text not null,
  customer_phone text,
  -- Intake channel, e.g. 'walk_in', 'online'. See lead_provider.dart comments.
  source text,
  stage text not null default 'new'
    check (stage in
      ('new', 'contacted', 'test_drive_scheduled', 'negotiating',
       'closed_won', 'closed_lost')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_leads_dealer on leads(dealer_id);
create index idx_leads_stage on leads(stage);

-- ============================================
-- LEAD ACTIVITY (interaction history/notes per lead)
-- ============================================
create table lead_activity (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null references leads(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  activity_type text not null,
  note text,
  created_at timestamptz default now()
);

create index idx_lead_activity_lead on lead_activity(lead_id);

-- ============================================
-- NOTIFICATIONS (staff and system alerts)
-- ============================================
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text check (type in ('lead', 'system')),
  is_read boolean default false,
  related_id uuid,
  created_at timestamptz default now()
);

create index idx_notifications_user on notifications(user_id, is_read);

-- ============================================
-- STAFF INVITES (pending invites for team onboarding)
-- ============================================
create table staff_invites (
  id uuid primary key default gen_random_uuid(),
  dealer_id uuid not null references dealers(id) on delete cascade,
  email text not null,
  role text not null default 'staff'
    check (role in ('owner', 'staff')),
  invited_by uuid references auth.users(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'revoked', 'expired')),
  expires_at timestamptz,
  created_at timestamptz default now()
);

create index idx_staff_invites_dealer on staff_invites(dealer_id);

-- ============================================
-- ADMIN ACTIVITY (superadmin audit trail)
-- ============================================
create table admin_activity (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references admin_users(id) on delete set null,
  action text not null,
  target_table text,
  target_id uuid,
  metadata jsonb,
  created_at timestamptz default now()
);

create index idx_admin_activity_admin on admin_activity(admin_id);

-- ============================================
-- AI USAGE LOG (tracking AI/automation operations, e.g. VIN decoding)
-- ============================================
create table ai_usage_log (
  id uuid primary key default gen_random_uuid(),
  dealer_id uuid references dealers(id) on delete cascade,
  feature text not null,
  tokens_used integer,
  cost numeric(10,4),
  created_at timestamptz default now()
);

create index idx_ai_usage_log_dealer on ai_usage_log(dealer_id);

-- ============================================
-- UPDATED_AT TRIGGER FUNCTION (reusable)
-- ============================================
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger set_updated_at_dealers
  before update on dealers
  for each row execute function update_updated_at_column();

create trigger set_updated_at_dealer_staff
  before update on dealer_staff
  for each row execute function update_updated_at_column();

create trigger set_updated_at_cars
  before update on cars
  for each row execute function update_updated_at_column();

create trigger set_updated_at_leads
  before update on leads
  for each row execute function update_updated_at_column();
