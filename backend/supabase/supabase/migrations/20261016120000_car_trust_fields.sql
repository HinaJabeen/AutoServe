-- ============================================
-- CARS — chassis number + inspection (anti-scam / trust)
-- ============================================
-- Additive only; safe to re-run. Nothing existing changes behaviour:
-- all three columns are nullable, and the uniqueness rule only covers rows
-- that actually set a chassis number.

alter table public.cars
  add column if not exists chassis_number varchar(50),
  add column if not exists inspection_score numeric(3, 1)
    check (inspection_score is null or (inspection_score >= 0 and inspection_score <= 10)),
  -- e.g. {"engine": 9.0, "suspension": 8.5, "body": "Non-Accidental"}
  add column if not exists inspection_details jsonb;

-- The same physical car can't be live twice — across ALL dealers, which is
-- the point: a scammer re-listing someone else's car (or a dealer
-- double-posting) is rejected with a unique violation (23505). Matching is
-- case/space-insensitive; sold/inactive listings don't count, so a car can
-- be re-listed after it's sold.
create unique index if not exists cars_active_chassis_number_key
  on public.cars (upper(btrim(chassis_number)))
  where chassis_number is not null
    and btrim(chassis_number) <> ''
    and status in ('available', 'reserved');
