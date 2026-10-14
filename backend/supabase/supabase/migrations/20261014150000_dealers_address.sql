-- ============================================
-- DEALERS — street address
-- ============================================
-- The live `dealers` table has only id, name, city, contact_phone, status,
-- created_at, business_hours (verified against the production API on
-- 2026-10-14). 20260630062555_initial_schema.sql claims phone/address/
-- owner_name/email/logo_url too, but none of those exist live. This adds
-- the one the Settings screen and the customer dealer card need.
-- Idempotent: safe to re-run.
alter table dealers
  add column if not exists address text
    check (address is null or char_length(address) <= 300);
