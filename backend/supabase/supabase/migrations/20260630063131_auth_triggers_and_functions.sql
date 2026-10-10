-- ============================================
-- AUTO-CREATE USER PROFILE ON SIGNUP
-- ============================================
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', 'User'),
    coalesce(new.raw_user_meta_data->>'role', 'consumer')
  );
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================
-- INCREMENT VEHICLE VIEW COUNT
-- Security definer so consumers can trigger this without
-- having direct UPDATE permission on vehicles table
-- ============================================
create or replace function increment_vehicle_views(target_vehicle_id uuid)
returns void as $$
begin
  update vehicles 
  set views_count = views_count + 1 
  where id = target_vehicle_id;
end;
$$ language plpgsql security definer set search_path = public;

-- ============================================
-- CREATE NOTIFICATION WHEN NEW LEAD IS CREATED
-- This is what powers your real-time demo moment
-- ============================================
create or replace function notify_dealer_on_new_lead()
returns trigger as $$
declare
  dealer_user_id uuid;
  vehicle_info text;
begin
  -- Get vehicle make/model for the notification text
  select make || ' ' || model into vehicle_info
  from vehicles where id = new.vehicle_id;

  -- Find the dealer owner for this dealership
  select id into dealer_user_id
  from users 
  where dealership_id = new.dealership_id 
  and role = 'dealer_owner'
  limit 1;

  if dealer_user_id is not null then
    insert into notifications (user_id, title, body, type, related_id)
    values (
      dealer_user_id,
      'New ' || new.type,
      new.consumer_name || ' is interested in ' || coalesce(vehicle_info, 'a vehicle'),
      'lead',
      new.id
    );
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_lead_created
  after insert on leads
  for each row execute function notify_dealer_on_new_lead();