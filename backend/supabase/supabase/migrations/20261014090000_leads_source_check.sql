-- ============================================
-- LEADS — source check constraint
-- ============================================
-- `leads.source` was a plain nullable text column in 20260630062555_initial_schema.sql
-- (no check constraint). The live Supabase project now has a
-- `leads_source_check` constraint that isn't reflected in any migration here
-- (added directly via the dashboard/SQL editor, out of band) and it was
-- rejecting the one insert this codebase actually performs
-- (`apps/customer/.../discovery_providers.dart` → `source: 'test_drive_request'`).
--
-- This migration is the first copy of that constraint checked into the repo,
-- covering every value the app sends today plus the two channels named in
-- the original column comment ('walk_in', 'online' — dashboard-side manual
-- entry) and 'swipe_interest' (the right-swipe lead, per
-- docs/architecture.md §8.2, not wired up yet but part of the same plan),
-- and 'inquiry' (the detail screen's "Send Inquiry" — LeadType.inquiry).
alter table leads drop constraint if exists leads_source_check;

alter table leads add constraint leads_source_check
  check (source is null or source in
    ('walk_in', 'online', 'test_drive_request', 'swipe_interest', 'inquiry'));
