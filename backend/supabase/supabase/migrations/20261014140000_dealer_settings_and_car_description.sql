-- ============================================
-- DEALER SETTINGS + PUBLIC CAR DESCRIPTION
-- ============================================
-- Columns only — no new tables or policies are needed:
--   * Dealer notes on leads reuse `lead_activity` (activity_type = 'note'),
--     already RLS-scoped to the lead's dealership.
--   * Owners already update their own `dealers` row via
--     "owners_update_own_dealer"; super admins via
--     "super_admin_full_access_dealers".
--   * The customer app already reads `dealers` (approved only) and public
--     `cars`, so the new columns are visible there without policy changes.
-- Idempotent: safe to re-run.

-- Free text, shown as-is to customers, e.g. "Mon–Sat 10am–8pm, Sun closed".
alter table dealers
  add column if not exists business_hours text
    check (business_hours is null or char_length(business_hours) <= 200);

-- Customer-facing listing description. Distinct from
-- `reconditioning_notes`, which is internal and never shown to customers.
alter table cars
  add column if not exists description text
    check (description is null or char_length(description) <= 2000);
