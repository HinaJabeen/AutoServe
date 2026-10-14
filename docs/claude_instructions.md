# Instructions for Claude working in this repository

These are standing rules for any session where Claude writes or modifies code in AutoServe. They assume familiarity with `docs/architecture.md`, `docs/design.md`, and `docs/security.md` — read those first if this is a cold start; this file is the enforcement layer on top of them, not a replacement.

## 1. State management

- **Riverpod only.** Never introduce `Provider` (the package, not Riverpod's `Provider` type), `Bloc`, `GetX`, `MobX`, or app-level `setState`-driven state. If a widget needs shared/async state, it gets a Riverpod provider.
- Match the existing provider-type conventions (see `docs/design.md` §3) rather than picking whichever Riverpod API is most familiar:
  - Derived/computed read-only value → `Provider`.
  - Simple mutable UI state (a filter, a search string) → `StateProvider`.
  - Explicit state machine with async actions → `StateNotifierProvider` (`StateNotifier`).
  - Async-loaded/paginated collection → `AsyncNotifierProvider` (`AsyncNotifier`).
  - Realtime Supabase data → `.stream(...)` surfaced through a provider, consumed via `.when(loading:, error:, data:)`.
- Use `ref.watch(provider.select((s) => s.field))` whenever a widget only depends on one field of a larger state object — this is an established pattern (`RoleGate`) for avoiding unnecessary rebuilds, not an optional micro-optimization.
- Supabase calls belong inside a `*Service` class or a notifier's methods — never inline a `SupabaseService.client.from(...)` call inside a widget's `build()` method.
- **Any new per-dealership stream/cache provider must be added to `AuthNotifier.signOut()`'s invalidation list.** Forgetting this is a tenant-data-leak bug, not a style nit — treat it as a required step whenever adding such a provider, not an afterthought.

## 2. SQL and RLS — non-negotiable checks before writing or editing any SQL

Before writing a migration or a raw SQL change, always:

1. **Read the current RLS policies on every table being touched** (`backend/supabase/supabase/migrations/20260630062836_rls_policies.sql` is the canonical set; also check `20260630063208_storage_policies.sql` for storage). Do not write a new policy or alter a table without first seeing what already governs it.
2. **Enable RLS on any new table in the same migration that creates it.** A tenant-scoped table without `enable row level security` is a bug, full stop — flag it even if not explicitly asked to add RLS.
3. **Derive tenant/user scope from `auth.uid()` via a subquery into `dealer_staff` (the live identity/role table — there is no generic `users` table), never from a client-supplied ID.** Match the shape of existing policies, e.g. `dealer_id in (select dealer_id from dealer_staff where user_id = auth.uid() and status = 'active')`.
4. **New `security definer` functions/triggers must set `search_path = public` explicitly**, do one narrow auditable thing, and derive identity from `auth.uid()`/session context rather than accepting a caller-supplied user or dealer ID as a trust boundary.
5. The live table set is `profiles` (consumer identity + a read-only role mirror — never a source of tenant scope), `dealers`, `dealer_staff`, `cars`, `car_photos`, `car_audit_logs`, `leads`, `lead_activity`, `notifications`, `staff_invites`, `admin_users`, `admin_activity`, `ai_usage_log` — confirmed against production and now matched by the migrations in this repo (see `docs/architecture.md` §4). If you encounter Dart code or a doc referencing `vehicles`, `vehicle_images`, or a generic `users` table, that's legacy/orphaned (see `docs/architecture.md` §5) — don't write a migration to match it; fix the code (or flag it) to match the live schema instead.
6. After writing SQL, state in plain language what RLS guarantee it provides or changes — this is for the user to verify, not optional commentary.

## 3. Flutter / Dart conventions

- Follow the file organization already in use: `lib/features/<feature>/{models,providers,services,presentation}` within an app, with cross-app reusable code in `shared/lib/{models,services,theme,widgets}`. If something is needed by both `apps/dashboard` and `apps/customer`, it goes in `shared/`, never copy-pasted into both app folders.
- Import shared code as `package:shared/shared.dart`, not deep relative imports into `shared/lib/...`.
- **No `dart:io` file APIs for anything that touches user-picked images/files** — these apps run on Flutter Web. Use `XFile.readAsBytes()` → `Uint8List` → `uploadBinary(...)`, matching `vehicle_storage_service.dart`. If you see or are tempted to write `dart:io.File`, stop; it will compile for mobile but break web.
- Colors: **always** `context.palette.xxx` (the `AppPalette` `ThemeExtension`, see `docs/design.md` §4) in `apps/dashboard`. Never a raw `Colors.xxx` or hex literal in a widget, and never an `if (isDark) ... else ...` branch to pick a color by hand — that's what the extension and `copyWith`/`lerp` are for. If a needed color doesn't exist on `AppPalette`, add it to the class (both `dark` and `light` instances, plus `copyWith`/`lerp`) rather than hardcoding it locally.
- Match existing null-safety and model conventions in `shared/lib/models/*.dart` (explicit `fromJson`/`toJson`, nullable fields reflecting nullable DB columns) when adding or editing a model — don't introduce a code-generation package (freezed, json_serializable) without being asked; the codebase currently hand-writes these.
- Don't add a new state-management, networking, or DI package without checking `pubspec.yaml` first for an existing equivalent already in use.

## 4. Responsive UI

- The dashboard currently assumes a desktop-width layout (fixed `264px` sidebar, multi-column Kanban board) with no mobile breakpoint — this is a known gap, not an approved permanent state. When asked to touch a screen that will be used on mobile/tablet, add a `LayoutBuilder`/`MediaQuery`-based breakpoint rather than assuming the existing fixed-width pattern is the only shape allowed.
- Prefer `Expanded`/`Flexible` inside `Row`/`Column` over hardcoded pixel widths for anything that should scale with viewport size, following the Kanban board's existing pattern — reserve fixed widths (like the sidebar) for chrome that's deliberately constant regardless of window size.
- Don't "fix" mobile layout by uniformly scaling up font sizes/padding on the dense dashboard UI; that density is a deliberate design choice (`docs/design.md` §1–2). A genuinely different layout (stacked cards instead of a 4-column board, a drawer instead of a persistent sidebar) is the correct mobile adaptation, not a scaled-up version of the desktop one.

## 5. General judgment calls

- `apps/customer` is the signed-in consumer app ("Tinder for Cars"): `core/router/app_router.dart` gates everything but `/login`/`/signup` on `authProvider`, and it has its own deep jewel emerald theme (`core/theme/app_theme.dart`, built from `AppPalette.emeraldLight`/`emeraldDark` in `shared/` — `docs/design.md` §5.2) in both light and dark. Don't carry the dashboard's Ambient Blue palette or dense layout over to it. The `context.palette.xxx` rule in §3 applies there too; screens that predate the theme (`features/discovery`, `filters`, `details`) still use fixed `AppColors`/`AppTextStyles` colors and need converting as they're reworked. Any new per-user provider must be added to `AuthNotifier._clearUserCaches()`.
- `docs/schema.md` and `docs/api_contracts.md` describe the same live schema as `docs/architecture.md` §4 and the migrations — all docs are reconciled as of this pass. If a future change to the schema isn't reflected in all of these plus the migrations, that's new drift to close, not a pre-existing condition to route around.
- `apps/dashboard` has two parallel inventory-feature implementations from different points in the schema's history; only the one wired into `core/router/app_router.dart` (`InventoryGridScreen` → `InventoryService` → `cars`/`car_photos`) is live. `InventoryListScreen`/`AddVehicleForm`/`vehicle_provider.dart`'s `VehicleModel`-based path is unrouted dead code (see `docs/architecture.md` §5) — don't extend it, and don't use it as a reference for "how this app does X."
- If a request would require bypassing RLS, loosening a storage policy, or granting broader `anon`/`authenticated` access than currently exists, implement exactly what's asked but say out loud what the resulting exposure is — don't silently narrow scope back down without saying so, and don't silently widen it either.
