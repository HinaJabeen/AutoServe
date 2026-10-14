-- ============================================
-- REALTIME — publish the tables the dashboard streams
-- ============================================
-- The dashboard watches `leads` (Kanban, notification bell) and `cars`
-- (overview metrics) with `.stream(primaryKey: ['id'])`. That call loads the
-- initial rows over REST, then waits for Postgres change events — which
-- Supabase only emits for tables in the `supabase_realtime` publication. No
-- earlier migration added them, so the board showed new leads only after a
-- page reload.
--
-- Change events are still filtered through each table's RLS select
-- policies, so staff only receive rows for their own dealership.
-- Idempotent: safe to re-run.
do $$
declare
  t text;
begin
  foreach t in array array['leads', 'cars'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
