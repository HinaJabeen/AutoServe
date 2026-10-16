-- ============================================
-- DEALERSHIP ONBOARDING & ANTI-SCAM VERIFICATION
-- ============================================
-- Written against the LIVE schema (verified via the production API on
-- 2026-10-14/15): dealers = id, name, city, contact_phone, status,
-- created_at, business_hours, address; dealer_staff = id, dealer_id,
-- user_id, full_name, role, status, requires_password_change;
-- admin_users = id, user_id, full_name, created_at.
--
-- DESIGN NOTE — why identity data is NOT on `dealers`:
-- approved `dealers` rows are readable by every customer and by anon (the
-- customer app shows dealer info on listings). Owner CNIC, phone, NTN and
-- document paths there would be public. So:
--   * dealers               — public-safe workflow fields (status, rejection
--                             reason, verified_at/by, showroom photo, the
--                             applicant link, submission time)
--   * dealer_verifications  — private identity + documents, readable only by
--                             the applicant and platform admins.
--
-- Document "*_url" columns hold Storage object PATHS, not URLs:
--   showroom_photo_url  → public bucket `dealership-photos` (getPublicUrl)
--   cnic_*/business_doc → private bucket `verification-documents`
--                         (createSignedUrl, admin/applicant only)
--
-- Idempotent: safe to re-run.

-- ── Platform admin check ────────────────────────────────────────────────
-- Live admin_users has both id and user_id; match either. SECURITY DEFINER
-- so it works regardless of admin_users' own RLS.
alter table public.admin_users
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

create or replace function public.is_platform_admin()
returns boolean
language plpgsql stable security definer set search_path = public
as $$
begin
  return auth.uid() is not null and exists (
    select 1 from public.admin_users
    where user_id = auth.uid() or id = auth.uid()
  );
end;
$$;

grant execute on function public.is_platform_admin() to authenticated;

-- ── dealers: workflow columns ───────────────────────────────────────────
alter table public.dealers
  add column if not exists applicant_user_id uuid references auth.users(id) on delete set null,
  add column if not exists showroom_photo_url text,
  add column if not exists rejection_reason text
    check (rejection_reason is null or char_length(rejection_reason) <= 500),
  add column if not exists submitted_at timestamptz,
  add column if not exists verified_at timestamptz,
  add column if not exists verified_by uuid references auth.users(id) on delete set null,
  add column if not exists address text;

-- One application per user account.
create unique index if not exists dealers_applicant_user_id_key
  on public.dealers (applicant_user_id) where applicant_user_id is not null;

-- status: replace whatever check the live table has (its name isn't known)
-- with the four-state workflow.
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.dealers'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table public.dealers drop constraint %I', c.conname);
  end loop;
end $$;

update public.dealers set status = 'pending' where status is null;
alter table public.dealers alter column status set default 'pending';
alter table public.dealers alter column status set not null;
alter table public.dealers add constraint dealers_status_check
  check (status in ('pending', 'approved', 'rejected', 'suspended'));

-- ── dealer_verifications: private identity + documents ─────────────────
create table if not exists public.dealer_verifications (
  dealer_id uuid primary key references public.dealers(id) on delete cascade,
  owner_full_name text not null check (char_length(owner_full_name) between 3 and 120),
  owner_cnic varchar(15) not null check (owner_cnic ~ '^\d{5}-\d{7}-\d$'),
  owner_phone text not null check (char_length(owner_phone) <= 20),
  ntn_number text check (ntn_number is null or char_length(ntn_number) <= 30),
  cnic_front_url text not null,
  cnic_back_url text not null,
  business_doc_url text not null,
  initial_inventory_info jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.dealer_verifications enable row level security;

drop policy if exists "applicant_view_own_verification" on public.dealer_verifications;
create policy "applicant_view_own_verification"
on public.dealer_verifications for select to authenticated
using (dealer_id in (select id from public.dealers where applicant_user_id = auth.uid()));

drop policy if exists "platform_admin_all_verifications" on public.dealer_verifications;
create policy "platform_admin_all_verifications"
on public.dealer_verifications for all to authenticated
using (public.is_platform_admin()) with check (public.is_platform_admin());

-- No insert/update policy for applicants: writes go through
-- submit_dealer_application() below.
revoke all on public.dealer_verifications from anon;

-- ── RLS additions on existing tables ────────────────────────────────────
-- Applicants can read their own dealer row while pending/rejected (approved
-- rows are already public).
drop policy if exists "applicant_view_own_dealer" on public.dealers;
create policy "applicant_view_own_dealer"
on public.dealers for select to authenticated
using (applicant_user_id = auth.uid());

-- Admin access keyed on is_platform_admin() (the older "super_admin_*"
-- policies compare admin_users.id only, which may not be the auth link).
drop policy if exists "platform_admin_all_dealers" on public.dealers;
create policy "platform_admin_all_dealers"
on public.dealers for all to authenticated
using (public.is_platform_admin()) with check (public.is_platform_admin());

drop policy if exists "platform_admin_read_cars" on public.cars;
create policy "platform_admin_read_cars"
on public.cars for select to authenticated using (public.is_platform_admin());

drop policy if exists "platform_admin_read_leads" on public.leads;
create policy "platform_admin_read_leads"
on public.leads for select to authenticated using (public.is_platform_admin());

-- ── Guard: only admins (or the functions below) change verification state
-- Owners have UPDATE on their own dealer row ("owners_update_own_dealer"),
-- which would otherwise let a suspended dealer set status = 'approved'.
create or replace function public.guard_dealer_verification_fields()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null                       -- service role / SQL editor
     or public.is_platform_admin()
     or current_setting('autoserve.application_write', true) = 'on' then
    return new;
  end if;

  if new.status is distinct from old.status
     or new.rejection_reason is distinct from old.rejection_reason
     or new.verified_at is distinct from old.verified_at
     or new.verified_by is distinct from old.verified_by
     or new.applicant_user_id is distinct from old.applicant_user_id
     or new.submitted_at is distinct from old.submitted_at then
    raise exception 'Only AutoServe admins can change a dealership''s verification status.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_dealer_verification_fields on public.dealers;
create trigger guard_dealer_verification_fields
  before update on public.dealers
  for each row execute function public.guard_dealer_verification_fields();

-- ── Submit / resubmit (applicant) ───────────────────────────────────────
-- One atomic call for both tables. Insert on first submission; on a
-- rejected (or still pending) application, update and put it back to
-- 'pending'. Approved/suspended applications can't be resubmitted.
create or replace function public.submit_dealer_application(
  p_showroom_name text,
  p_city text,
  p_address text,
  p_whatsapp text,
  p_business_hours text,
  p_showroom_photo_path text,
  p_owner_full_name text,
  p_owner_cnic text,
  p_owner_phone text,
  p_ntn_number text,
  p_cnic_front_path text,
  p_cnic_back_path text,
  p_business_doc_path text,
  p_inventory_info jsonb
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_dealer public.dealers%rowtype;
  v_prefix text;
begin
  if v_uid is null then
    raise exception 'Sign in to apply.' using errcode = '42501';
  end if;
  if public.is_platform_admin() then
    raise exception 'Admin accounts cannot apply as a dealer.';
  end if;

  -- Uploaded files must be the applicant's own (storage folder = their uid).
  v_prefix := v_uid::text || '/';
  if left(p_showroom_photo_path, length(v_prefix)) <> v_prefix
     or left(p_cnic_front_path, length(v_prefix)) <> v_prefix
     or left(p_cnic_back_path, length(v_prefix)) <> v_prefix
     or left(p_business_doc_path, length(v_prefix)) <> v_prefix then
    raise exception 'Uploaded documents must belong to the applicant.' using errcode = '42501';
  end if;

  perform set_config('autoserve.application_write', 'on', true);

  select * into v_dealer from public.dealers where applicant_user_id = v_uid;

  if found then
    if v_dealer.status not in ('pending', 'rejected') then
      raise exception 'This application is already %.', v_dealer.status;
    end if;
    update public.dealers set
      name = p_showroom_name, city = p_city, address = p_address,
      contact_phone = p_whatsapp, business_hours = p_business_hours,
      showroom_photo_url = p_showroom_photo_path,
      status = 'pending', rejection_reason = null, submitted_at = now()
    where id = v_dealer.id;
  else
    insert into public.dealers (
      name, city, address, contact_phone, business_hours,
      showroom_photo_url, status, applicant_user_id, submitted_at
    ) values (
      p_showroom_name, p_city, p_address, p_whatsapp, p_business_hours,
      p_showroom_photo_path, 'pending', v_uid, now()
    ) returning * into v_dealer;
  end if;

  insert into public.dealer_verifications (
    dealer_id, owner_full_name, owner_cnic, owner_phone, ntn_number,
    cnic_front_url, cnic_back_url, business_doc_url, initial_inventory_info
  ) values (
    v_dealer.id, p_owner_full_name, p_owner_cnic, p_owner_phone,
    nullif(trim(p_ntn_number), ''),
    p_cnic_front_path, p_cnic_back_path, p_business_doc_path,
    coalesce(p_inventory_info, '{}'::jsonb)
  )
  on conflict (dealer_id) do update set
    owner_full_name = excluded.owner_full_name,
    owner_cnic = excluded.owner_cnic,
    owner_phone = excluded.owner_phone,
    ntn_number = excluded.ntn_number,
    cnic_front_url = excluded.cnic_front_url,
    cnic_back_url = excluded.cnic_back_url,
    business_doc_url = excluded.business_doc_url,
    initial_inventory_info = excluded.initial_inventory_info,
    updated_at = now();

  return v_dealer.id;
end;
$$;

revoke all on function public.submit_dealer_application(
  text, text, text, text, text, text, text, text, text, text, text, text, text, jsonb
) from public, anon;
grant execute on function public.submit_dealer_application(
  text, text, text, text, text, text, text, text, text, text, text, text, text, jsonb
) to authenticated;

-- ── Approve / reject (admin) ────────────────────────────────────────────
create or replace function public.approve_dealer_application(p_dealer_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_dealer public.dealers%rowtype;
  v_owner_name text;
  v_staff public.dealer_staff%rowtype;
begin
  if not public.is_platform_admin() then
    raise exception 'Only AutoServe admins can approve dealerships.' using errcode = '42501';
  end if;

  select * into v_dealer from public.dealers where id = p_dealer_id for update;
  if not found then
    raise exception 'Dealership not found.';
  end if;

  update public.dealers set
    status = 'approved', rejection_reason = null,
    verified_at = now(), verified_by = auth.uid()
  where id = p_dealer_id;

  -- Make the applicant the dealership's owner so they can sign in to the
  -- dealer dashboard. (Admin-registered dealers have no applicant.)
  if v_dealer.applicant_user_id is not null then
    select owner_full_name into v_owner_name
      from public.dealer_verifications where dealer_id = p_dealer_id;

    select * into v_staff from public.dealer_staff
      where user_id = v_dealer.applicant_user_id;

    if found and v_staff.dealer_id <> p_dealer_id then
      raise exception 'The applicant already belongs to another dealership.';
    elsif found then
      update public.dealer_staff set role = 'owner', status = 'active'
        where id = v_staff.id;
    else
      insert into public.dealer_staff (
        dealer_id, user_id, full_name, role, status, requires_password_change
      ) values (
        p_dealer_id, v_dealer.applicant_user_id,
        coalesce(v_owner_name, v_dealer.name), 'owner', 'active', false
      );
    end if;
  end if;
end;
$$;

create or replace function public.reject_dealer_application(p_dealer_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Only AutoServe admins can reject dealerships.' using errcode = '42501';
  end if;
  if p_reason is null or char_length(trim(p_reason)) < 5 then
    raise exception 'A rejection reason (at least 5 characters) is required.';
  end if;

  update public.dealers set
    status = 'rejected', rejection_reason = trim(p_reason),
    verified_at = null, verified_by = auth.uid()
  where id = p_dealer_id;
  if not found then
    raise exception 'Dealership not found.';
  end if;
end;
$$;

revoke all on function public.approve_dealer_application(uuid) from public, anon;
revoke all on function public.reject_dealer_application(uuid, text) from public, anon;
grant execute on function public.approve_dealer_application(uuid) to authenticated;
grant execute on function public.reject_dealer_application(uuid, text) to authenticated;

-- ── Storage buckets ─────────────────────────────────────────────────────
-- Objects are stored under "<auth uid>/..." so policies can scope by owner.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('dealership-photos', 'dealership-photos', true, 10485760,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('verification-documents', 'verification-documents', false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public_read_dealership_photos" on storage.objects;
create policy "public_read_dealership_photos"
on storage.objects for select to public
using (bucket_id = 'dealership-photos');

drop policy if exists "owner_upload_dealership_photos" on storage.objects;
create policy "owner_upload_dealership_photos"
on storage.objects for insert to authenticated
with check (bucket_id = 'dealership-photos'
            and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "owner_delete_dealership_photos" on storage.objects;
create policy "owner_delete_dealership_photos"
on storage.objects for delete to authenticated
using (bucket_id = 'dealership-photos'
       and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "owner_upload_verification_documents" on storage.objects;
create policy "owner_upload_verification_documents"
on storage.objects for insert to authenticated
with check (bucket_id = 'verification-documents'
            and (storage.foldername(name))[1] = auth.uid()::text);

-- Readable only by the uploader and platform admins — never other dealers.
drop policy if exists "owner_or_admin_read_verification_documents" on storage.objects;
create policy "owner_or_admin_read_verification_documents"
on storage.objects for select to authenticated
using (bucket_id = 'verification-documents'
       and ((storage.foldername(name))[1] = auth.uid()::text
            or public.is_platform_admin()));

drop policy if exists "owner_delete_verification_documents" on storage.objects;
create policy "owner_delete_verification_documents"
on storage.objects for delete to authenticated
using (bucket_id = 'verification-documents'
       and (storage.foldername(name))[1] = auth.uid()::text);
