-- ============================================
-- AUTH TRIGGERS & FUNCTIONS — reconciled against live schema
-- ============================================
-- Supersedes the earlier version of this migration.
--
-- Dropped: handle_new_user() / on_auth_user_created trigger. The old schema
-- auto-inserted every new auth.users signup into a generic `users` row with
-- role defaulting to 'consumer'. That table doesn't exist in the live
-- schema, and there is no generic consumer-identity table at all — the
-- customer-facing portal captures leads by name/phone (leads.customer_name/
-- customer_phone) without requiring an account. Staff accounts are instead
-- provisioned explicitly into dealer_staff (via invite) or admin_users
-- (manually, for superadmins); there is no safe generic default role to
-- assign a bare signup, so no blanket signup trigger is installed.
--
-- Dropped: increment_vehicle_views(). The live `cars` table has no
-- views_count column and no Dart code calls this RPC — it belonged to the
-- old `vehicles` schema. Re-add it (with the column) if/when the customer
-- portal needs view tracking.

-- ============================================
-- CREATE NOTIFICATION WHEN NEW LEAD IS CREATED
-- Mirrors lead_provider.dart / overview_provider.dart's column mapping:
-- leads.dealer_id, leads.car_id, leads.customer_name.
-- ============================================
create or replace function notify_dealer_on_new_lead()
returns trigger as $$
declare
  owner_user_id uuid;
  car_info text;
begin
  -- Get make/model for the notification text, if this lead references a car.
  if new.car_id is not null then
    select make || ' ' || model into car_info
    from cars where id = new.car_id;
  end if;

  -- Find the active dealer owner for this dealership.
  select user_id into owner_user_id
  from dealer_staff
  where dealer_id = new.dealer_id
    and role = 'owner'
    and status = 'active'
  limit 1;

  if owner_user_id is not null then
    insert into notifications (user_id, title, body, type, related_id)
    values (
      owner_user_id,
      'New lead',
      new.customer_name || ' is interested in ' || coalesce(car_info, 'a vehicle'),
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

-- ============================================
-- LOG CAR CHANGES TO car_audit_logs
-- Captures status/price/mileage updates made via InventoryService
-- (lib/features/inventory/services/inventory_service.dart) without
-- requiring the client to have direct insert rights on car_audit_logs.
-- ============================================
create or replace function log_car_update()
returns trigger as $$
begin
  if new.status is distinct from old.status
     or new.price is distinct from old.price
     or new.mileage is distinct from old.mileage then
    insert into car_audit_logs (car_id, actor_id, action, old_value, new_value)
    values (
      new.id,
      auth.uid(),
      'update',
      jsonb_build_object('status', old.status, 'price', old.price, 'mileage', old.mileage),
      jsonb_build_object('status', new.status, 'price', new.price, 'mileage', new.mileage)
    );
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger on_car_updated
  after update on cars
  for each row execute function log_car_update();
