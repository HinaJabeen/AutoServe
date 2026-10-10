-- ============================================
-- AUTOSERVE INITIAL SCHEMA
-- ============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================
-- DEALERSHIPS
-- ============================================
create table dealerships (
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
-- USERS (extends Supabase auth.users)
-- ============================================
create table users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  full_name text not null,
  phone text,
  role text not null
    check (role in ('super_admin', 'dealer_owner', 
                    'salesperson', 'consumer')),
  dealership_id uuid references dealerships(id),
  avatar_url text,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- VEHICLES
-- ============================================
create table vehicles (
  id uuid primary key default gen_random_uuid(),
  dealership_id uuid not null references dealerships(id) on delete cascade,
  make text not null,
  model text not null,
  year integer not null check (year >= 1980 and year <= 2030),
  color text,
  mileage integer not null check (mileage >= 0),
  price numeric(12,2) not null check (price > 0),
  condition text check (condition in ('new', 'used', 'certified')),
  fuel_type text check (fuel_type in 
    ('petrol', 'diesel', 'hybrid', 'electric')),
  transmission text check (transmission in 
    ('manual', 'automatic')),
  body_type text check (body_type in 
    ('sedan', 'suv', 'hatchback', 'pickup', 
     'van', 'coupe', 'convertible')),
  description text,
  status text default 'available'
    check (status in ('available', 'reserved', 'sold', 'inactive')),
  views_count integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index for common query patterns
create index idx_vehicles_dealership on vehicles(dealership_id);
create index idx_vehicles_status on vehicles(status);
create index idx_vehicles_make_model on vehicles(make, model);

-- ============================================
-- VEHICLE IMAGES
-- ============================================
create table vehicle_images (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  image_url text not null,
  is_primary boolean default false,
  display_order integer default 0,
  created_at timestamptz default now()
);

create index idx_vehicle_images_vehicle on vehicle_images(vehicle_id);

-- ============================================
-- LEADS
-- ============================================
create table leads (
  id uuid primary key default gen_random_uuid(),
  dealership_id uuid not null references dealerships(id) on delete cascade,
  vehicle_id uuid references vehicles(id) on delete set null,
  consumer_id uuid references users(id),
  consumer_name text not null,
  consumer_phone text,
  consumer_email text,
  type text check (type in ('inquiry', 'test_drive')),
  status text default 'new'
    check (status in ('new', 'contacted', 'closed_won', 'closed_lost')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_leads_dealership on leads(dealership_id);
create index idx_leads_status on leads(status);

-- ============================================
-- NOTIFICATIONS
-- ============================================
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  title text not null,
  body text not null,
  type text check (type in ('lead', 'system')),
  is_read boolean default false,
  related_id uuid,
  created_at timestamptz default now()
);

create index idx_notifications_user on notifications(user_id, is_read);

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

create trigger set_updated_at_dealerships
  before update on dealerships
  for each row execute function update_updated_at_column();

create trigger set_updated_at_users
  before update on users
  for each row execute function update_updated_at_column();

create trigger set_updated_at_vehicles
  before update on vehicles
  for each row execute function update_updated_at_column();

create trigger set_updated_at_leads
  before update on leads
  for each row execute function update_updated_at_column();