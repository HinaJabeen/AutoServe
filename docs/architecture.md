# AutoServe — System Architecture

## 1. What AutoServe is

AutoServe is a multi-sided automotive SaaS ecosystem on a single multi-tenant architecture, serving three distinct user groups:

1. **Public consumers** — a discovery portal (target UX: a swipeable "Tinder for Cars" deck) for finding cars by spec, matching with dealers, and booking test drives.
2. **Dealership operators** — a dense, multi-tenant operations dashboard: live analytics, real-time inventory management, and a drag-and-drop Kanban CRM pipeline.
3. **Platform superadmins** — a governance suite for tenant onboarding, platform health, and audit logs.

A single Supabase project backs all three; tenancy and role-based access are enforced at the database layer (RLS), not by the client. See §6 for the full feature/module breakdown and current build status of each.

Two first-party Flutter clients today, one shared backend:

```
┌─────────────────────┐     ┌─────────────────────┐
│   apps/dashboard     │     │   apps/customer      │
│   (dealer-facing,    │     │   (public showroom,  │
│   staff + admin)     │     │   consumer-facing)   │
└──────────┬───────────┘     └──────────┬───────────┘
           │                            │
           │        shared/ (models, theme, widgets, SupabaseService)
           │                            │
           └────────────┬───────────────┘
                         ▼
              ┌─────────────────────┐
              │   Supabase project   │
              │  (Postgres + Auth +  │
              │   Storage + RLS)     │
              └─────────────────────┘
```

There is **no custom backend server**. Supabase is the entire backend: Postgres database, authentication, file storage, and realtime subscriptions. Both Flutter apps talk to Supabase directly over its generated REST/Realtime API using the `supabase_flutter` SDK. Business rules that must not be trusted to the client (tenant isolation, role checks) live in Postgres as Row Level Security policies and `security definer` functions — not in app code.

A dedicated superadmin client/section (user group 3) does not exist as a Flutter surface yet — see §6, Module 4.

## 2. Repository layout

```
autoserve/
├── apps/
│   ├── dashboard/           # Dealer-facing web/desktop app (staff, owners, admins)
│   │   └── lib/
│   │       ├── core/router/      # go_router config + auth-aware redirects
│   │       ├── features/
│   │       │   ├── inventory/    # vehicle CRUD, CSV import, image upload, VIN decode
│   │       │   ├── providers/    # auth_provider, lead_provider, overview_provider, vehicle_provider
│   │       │   └── presentation/ # screens: login, leads, schedule, profile, overview
│   │       ├── layout/            # DashboardShell (sidebar + ambient background)
│   │       ├── theme/             # AppPalette (ThemeExtension), AppTheme, theme_provider
│   │       └── widgets/           # RoleGate, theme toggle, QR button
│   │
│   └── customer/            # Public-facing showroom app (browse, search, test-drive requests)
│       └── lib/main.dart    # scaffolded; screens not yet implemented
│
├── shared/                  # Published as a path package: shared/
│   └── lib/
│       ├── models/          # VehicleModel, LeadModel, DealershipModel, UserModel, NotificationModel
│       ├── services/        # SupabaseService (client singleton + init)
│       ├── theme/            # AppColors, AppDimensions, AppTextStyles (cross-app design tokens)
│       └── widgets/          # AppButton, AppTextField, VehicleCard, LoadingShimmer, ErrorState, EmptyState
│
└── backend/supabase/
    └── supabase/migrations/ # SQL: schema → RLS policies → auth triggers → storage policies
```

Both apps declare `shared` as a local path dependency (`shared: { path: ../../shared }`) and import it as `package:shared/shared.dart`. Nothing in `shared/` ever imports from `apps/dashboard` or `apps/customer` — the dependency direction is one-way. New cross-app models or widgets belong in `shared/`, never duplicated into an app folder (see `docs/setup.md`).

A root-level `lib/main.dart`, `pubspec.yaml`, and `web/` also exist from the original single-app scaffold; the two apps under `apps/` are the actively developed surfaces.

## 3. Client ↔ Supabase relationship

Each app calls `SupabaseService.initialize(url, anonKey)` once at startup (from `.env`, never committed), after which `SupabaseService.client` is a process-wide singleton (`shared/lib/services/supabase_service.dart`). All data access goes through this client:

- **Reads/writes** — `.from('table').select()/.insert()/.update()/.delete()`, filtered with `.eq()` etc. Postgres enforces RLS on every call using the caller's JWT; the app never has to remember "only show my dealer's rows" — the database refuses to return rows it shouldn't.
- **Realtime** — the dashboard's lead pipeline subscribes with `.stream(primaryKey: ['id'])` so the Kanban board and the notification bell update live when a new lead lands (`apps/dashboard/lib/features/providers/lead_provider.dart`, `overview_provider.dart`).
- **Triggers** — server-side side effects that must not depend on the client run as Postgres triggers with `security definer`, e.g. `notify_dealer_on_new_lead` (fires a notification row when a lead is inserted) and `log_car_update` (writes a `car_audit_logs` row when a car's status/price/mileage changes). No Dart code currently calls `.rpc(...)` directly — the live schema's side effects are all trigger-driven rather than explicitly invoked.
- **Storage** — vehicle photos and dealer logos go to separate Storage buckets (`vehicle-photos`, `dealer-logos`). Uploads use `uploadBinary()` with raw `Uint8List` from `XFile.readAsBytes()` (see `vehicle_storage_service.dart`) specifically because `dart:io File` does not exist on Flutter Web — this is a hard constraint, not a style choice.

## 4. Multi-tenancy model

Tenancy is enforced at the database layer, not in Dart code. **The live Supabase schema** (confirmed against production and now matched by `backend/supabase/supabase/migrations/`) is:

| Table | Purpose |
|---|---|
| `profiles` | One row per `auth.users` account — consumer `full_name`/`phone`, plus a trigger-maintained `role` mirror (`customer`/`dealer`/`admin`) used by `apps/customer` to turn staff accounts away |
| `dealers` | Tenant dealership accounts (`status`: `pending`/`approved`/`suspended`) |
| `dealer_staff` | Staff profiles — links a `dealer_id` + an `auth.users` `user_id`, carries `role` (`owner`/`staff`) and `status` (`active`/`deactivated`) |
| `cars` | Inventory vehicles belonging to a dealership (`dealer_id` FK) |
| `car_photos` | Storage paths + display metadata for a car's photos (`car_id` FK) |
| `car_audit_logs` | History/audit trail for inventory actions (`car_id` FK) |
| `leads` | CRM inquiries/sales-pipeline leads (`dealer_id`, nullable `car_id` FK) |
| `lead_activity` | Interaction history/notes per lead (`lead_id` FK) |
| `notifications` | Staff/system alerts (`user_id` → `auth.users`) |
| `staff_invites` | Pending team-onboarding invites (`dealer_id` FK) |
| `admin_users` | Superadmin/platform-level access (`id` → `auth.users`) |
| `admin_activity` | Superadmin audit trail |
| `ai_usage_log` | Tracking for AI/automation operations (VIN decoding, etc.) |

- Every tenant-scoped table (`cars`, `car_photos` via `cars`, `leads`, `staff_invites`, `ai_usage_log`) carries or resolves to a `dealer_id` foreign key on `dealers`, with `on delete cascade` so removing a dealer cleans up its rows.
- `dealer_staff.dealer_id` links a staff member to their dealership; `dealer_staff.role` (`owner`/`staff`) plus `dealer_staff.status` (`active`/`deactivated`) drive both RLS policies and UI-level `RoleGate`/`AppRole` checks in `auth_provider.dart`. There is **no generic `users` table** — that belonged to an earlier, outdated schema iteration and has been fully retired from the migrations.
- RLS policies (see `docs/security.md`) use `dealer_id in (select dealer_id from dealer_staff where user_id = auth.uid() and status = 'active')` as the standard isolation pattern: a staff member's queries are implicitly filtered to their own dealership by Postgres itself, so a bug in the Flutter query-building code cannot leak another dealer's data.
- Consumer identity lives in **`profiles`** (`backend/supabase/supabase/migrations/20261013160000_customer_profiles.sql`). `apps/customer` requires sign-in; signup creates the row via the `handle_new_user()` trigger. It is not a tenancy table — `profiles.role` only mirrors `dealer_staff`/`admin_users` and no RLS policy reads it. `leads` still stores `customer_name`/`customer_phone` directly and its open-insert policies are unchanged (see `docs/security.md` §2). Superadmin access is a separate, explicit `admin_users` table, not a role flag on a shared identity table.
- `dealers.status` (`pending`/`approved`/`suspended`) gates whether a dealer is visible to the public portal and whether its staff can act — enforced by the `public_view_approved_dealers` policy.

This supersedes an earlier draft of this document (and of the migrations) that modeled tenancy around `vehicles`/`vehicle_images`/generic `users` tables — that schema was never live; `cars`/`dealer_staff` and the rest of the table list above are the confirmed production schema.

## 5. Live vs. orphaned code paths in `apps/dashboard`

The dashboard contains two parallel implementations of the vehicle-inventory feature, from two different points in the schema's history. Only one is actually reachable:

- **Live path** (wired to `/inventory` in `core/router/app_router.dart`): `InventoryGridScreen` → `inventory_providers.dart`/`inventoryListProvider` → `InventoryService` → the `cars`/`car_photos` tables, using `CarModel`. Photo upload goes through `vehicle_form_v2.dart` → `vehicleFormProvider.uploadPhotos()` → `VehicleStorageService`.
- **Orphaned path** (not referenced by any route): `InventoryListScreen`/`AddVehicleForm` → `vehicle_provider.dart`/`dealerVehiclesStreamProvider` → `shared`'s `VehicleModel`, reading/writing the old `vehicles`-shaped columns through the `cars` table's `specs` JSON blob (`VehicleNotifier.addVehicle`/`updateVehicle` in `vehicle_provider.dart`). `shared/lib/models/user_model.dart` (`UserModel`) is similarly unused by any current code path.

Both pipelines happened to share `VehicleStorageService`, which is why a real bug lived there until this pass: it uploaded to a bucket name (`vehicles`) that matched neither the storage policies (`vehicle-images`) nor the bucket `InventoryService` read from (`vehicle-photos`), and it wrote uploaded photo URLs into `cars.specs.images` — a column the live read path (`InventoryService._withPhotoUrls`, joining `car_photos`) never looks at. Photos uploaded through the live Add/Edit Vehicle form would silently never appear in the inventory grid. Fixed: `VehicleStorageService` now uploads to `vehicle-photos` and inserts a `car_photos` row per photo, matching what `InventoryService` reads.

Treat the orphaned path as dead code to be removed or deliberately revived, not as a second source of truth — don't copy patterns from `vehicle_provider.dart`/`AddVehicleForm` into new work on the live inventory feature.

## 6. Feature modules (spec vs. current build status)

This is the full target feature set. For each module: what it is, and what's actually built today.

### Module 1 — Multi-role authentication & routing ("gatekeeper")

One unified login screen authenticates via Supabase Auth, then routes by role:

- Superadmin → Platform Superadmin Panel.
- Dealer owner / staff ("sales rep") → Dealership CRM, data scoped by `dealer_id` via RLS.
- Everyone else (no staff/admin row) → the public Consumer app.

**Built:** `apps/dashboard`'s `LoginScreen` + `AuthNotifier` (`auth_provider.dart`) resolve `dealer_staff` → `AppRole.dealerOwner`/`AppRole.staff`, and `go_router`'s `refreshListenable` redirects accordingly. `dealer_staff.role` only has two values, `owner`/`staff` — "dealer_owner"/"sales_rep" in product language map onto those two, there's no separate `sales_rep` enum value to add.
**Correction to the routing spec above:** admin resolution must come from **`admin_users`**, not a `public.users` table — there is no generic `users` table in the live schema (see §4). `auth_provider.dart`'s current `users`-table fallback branch is dead/wrong code reaching for a table that doesn't exist (`docs/security.md` §1) and should be repointed at `admin_users`, not treated as already correct.
**Not built:** nothing routes to a superadmin panel yet (it doesn't exist — Module 4), and the dashboard login doesn't hand consumers off anywhere — `apps/customer` is a separate app with its own login/signup (`features/auth/`), which in turn blocks dealer/admin accounts.

### Module 2 — Consumer app: "Tinder for Cars"

- Swipeable vehicle deck: right = "Interested" (save + quick inquiry), left = "Pass", up = "Book Test Drive" (opens a scheduling modal against a specific dealer).
- Dynamic filter matrix: real-time filtering by make/model/year/mileage/body type/fuel type and dealer distance.
- Deep-dive specs: tap a card → full-screen image carousel + spec breakdown + dealer info.

**Built:** nothing yet. `apps/customer/lib/main.dart` renders a bare `Placeholder()`. See §8 for the implementation plan and the schema gap this module needs filled before it can be built (consumer-side persistence for swipes/saves doesn't exist today).

### Module 3 — Live dealership CRM & dashboard

- Live analytics: monthly sales velocity (area chart), inventory distribution (donut chart), live lead conversion rate; metric cards for gross stock value, active leads, cars sold this month.
- Drag-and-drop Kanban pipeline: New Inquiry → Contacted → Test Drive Booked → Negotiation → Closed Won/Lost, updating `leads.stage` live, with a quick-notes overlay writing to `lead_activity`.
- Vehicle inventory manager: grid/table of `cars`, add/edit flow with web-safe `Uint8List` image uploads to `car_photos`.

**Built:**
- Kanban pipeline (`lead_inbox_screen.dart`) — drag-and-drop across 4 stage columns, realtime via `dealerLeadsStreamProvider`, updates `leads.stage`. Its stage set is `new`/`contacted`/`test_drive_scheduled`/`negotiating` (+ `closed_won`/`closed_lost` as non-column chips) — functionally equivalent to the spec's stage names.
- Inventory manager (`InventoryGridScreen`/`InventoryService`/`vehicle_form_v2.dart`) — grid view, add/edit, web-safe `Uint8List` upload to `car_photos` (see §5 for the upload-path bug that was fixed).
- `OverviewScreen` renders `fl_chart` visuals today, but reading `cars`/`leads` once via `FutureProvider`/derived `Provider`s off a `StreamProvider` snapshot — not literally the live area/donut-chart set named in the spec yet.
**Not built:** `lead_activity` has a table (see §4) but nothing in the dashboard writes to it yet — there's no "quick sales note" overlay. See §8 for the charts implementation plan.

### Module 4 — Platform superadmin panel

- Master table of all `dealers`: approve/suspend, cross-platform analytics, audit log viewer over `admin_activity`/`ai_usage_log`.

**Built:** nothing. `admin_users`/`admin_activity` exist as tables (§4) with RLS already in place for a future admin surface, but there is no Flutter screen, route, or app that reads them. This is a from-scratch module.

## 7. Why no custom backend

Supabase provides auth, Postgres, storage, and realtime out of the box, and RLS gives tenant isolation stronger guarantees than an app-layer `WHERE dealership_id = ?` ever could (a forgotten filter is a data breach with a hand-rolled backend; with RLS it's a Postgres permission error). The tradeoff is that **business logic that can't be expressed as a row-level policy or a simple trigger has nowhere to live except the client** — there is no API layer to put it in. Keep this in mind before reaching for a "we'll just add a backend endpoint" solution; the answer is usually a Postgres function (`security definer` if it needs elevated rights) or a Supabase Edge Function, not a new service.

## 8. Implementation plan: Live CRM Charts & Swipe Deck

Two concrete build-outs from Module 2 and Module 3. Neither is started; this is the plan for building both on the current Riverpod + Supabase-realtime architecture.

### 8.1 Live CRM Charts (Module 3)

**Goal:** `OverviewScreen`'s metric cards and `fl_chart` visuals (sales velocity, inventory donut, lead conversion) update live as `cars`/`leads` change, not just on first load.

1. **Data layer — realtime-first, not fetch-once.** Replace `overview_provider.dart`'s one-shot `FutureProvider<List<MonthlyRevenue>>` (`revenueMonthlyProvider`) with a `StreamProvider` built the same way `dealerCarsStreamProvider`/`dealerLeadsStreamProvider` already are: `.from('cars').stream(primaryKey: ['id']).eq('dealer_id', dealerId)`. Supabase realtime streams emit the *full current row set* on every change (not deltas), so aggregation (bucket-by-month, sum revenue, count by status) stays a pure function applied inside a derived `Provider` that watches the stream — exactly the existing `dashboardMetricsProvider`/`inventoryAgingProvider` pattern. No new infrastructure needed, just extending the pattern that's already half-applied.
2. **Fix the aggregation gap**: `revenueMonthlyProvider` currently queries `cars` directly instead of deriving from `dealerCarsStreamProvider`, so it's the one metric that *doesn't* update live. Rewrite it as a `Provider` (not `FutureProvider`) that watches `dealerCarsStreamProvider` and buckets sold cars by `updated_at` month — same math it has today, just reactive to the stream instead of running once.
3. **Chart widgets** (`fl_chart`, already a dependency): keep `OverviewScreen`'s existing `LineChart`/structure; swap its data source from `ref.watch(revenueMonthlyProvider).when(...)` (AsyncValue from a FutureProvider) to `ref.watch(revenueMonthlyProvider)` as a plain `Provider<List<MonthlyRevenue>>` derived from the stream — `AsyncValue` handling moves up to wherever the underlying `StreamProvider` is first watched (`dealerCarsStreamProvider`'s `.when(loading:, error:, data:)`), same as `dashboardMetricsProvider` already does.
4. **Donut (inventory distribution) and conversion-rate charts**: both are pure derivations of `dealerCarsStreamProvider`/`dealerLeadsStreamProvider` already in memory — no new Supabase query needed, just new `Provider`s (e.g. `inventoryDistributionProvider`, `leadConversionRateProvider`) next to the existing `inventoryAgingProvider` in `overview_provider.dart`, each a `.whenData` map over the same two streams `OverviewScreen` already watches.
5. **Metric cards** (gross stock value, active leads, sold this month): extend `DashboardMetrics` (already in `overview_provider.dart`) with `grossStockValue` (`sum(price) where status='available'`) — everything else it needs (`totalVehicles`, `newLeadsToday`, `soldVehicles`) already exists.
6. **Performance**: Supabase's `.stream()` re-sends the whole table slice per dealer on every write, which is fine at current data volumes (one dealer's inventory/leads) but worth flagging if a dealer's `cars`/`leads` table grows large — the mitigation then is a materialized view or a scheduled aggregate table, not something to build preemptively now.

No schema changes needed — this is entirely a Riverpod-layer rewrite from fetch-once to stream-derived.

### 8.2 "Tinder for Cars" Swipe Deck (Module 2)

**Goal:** a gesture-driven card stack in `apps/customer` (currently just a `Placeholder()`) with right/left/up swipe semantics.

**Schema gap to resolve first:** the live schema (`docs/architecture.md` §4) has no consumer-identity or saved-swipe table — by design, `leads` accepts anonymous inserts with no account needed. But "Swipe Right saves to profile" and a persistent "Pass" skip-list both imply some durable per-visitor state, which doesn't exist yet. Two options, in increasing order of commitment:
  - **Device-local only** (fastest, zero schema change): persist swipe decisions in `shared_preferences`/local storage keyed by car ID. "Interested" immediately triggers a `leads` insert (no profile needed — this already matches the live insert-only RLS policy). No cross-device continuity, no "saved for later" account page.
  - **A `consumer_saves` table** (`id`, `car_id`, a device/session identifier or an opt-in `auth.users` id if the portal later adds lightweight consumer accounts, `direction` ['interested'/'passed'], `created_at`), insert-only via `anon`, RLS-scoped by the device/session identifier rather than `auth.uid()` since there's no required login. This is a real product decision (does AutoServe want anonymous session identity, or require light signup to swipe?) — flag it back rather than deciding unilaterally when the time comes to build this.

  This plan proceeds with the device-local approach for v1, since it needs no new migration and matches "no login wall for browsing" already established for `cars`/`car_photos` anon-read policies.

1. **Package**: add a swipe-card package (e.g. `flutter_card_swiper` or `appinio_swiper`) to `apps/customer/pubspec.yaml` rather than hand-rolling gesture physics — both expose `onSwipe(index, direction)` callbacks that map directly onto right/left/up.
2. **Data layer**: `carDeckProvider` — a `StreamProvider<List<CarModel>>` (reuse the dashboard's `CarModel`, moved to `shared/` if it isn't already reusable across apps — currently it lives under `apps/dashboard/lib/features/inventory/models/`, which `apps/customer` can't import; promoting it to `shared/lib/models/car_model.dart` is a prerequisite step) filtered server-side by the **Dynamic Filter Matrix** state (`make`/`model`/`year`/`mileage`/`bodyType`/`fuelType`, each a `StateProvider`, composed into the query the same way `inventorySearchProvider`/`inventoryStatusFilterProvider` compose in `inventory_providers.dart`). Base query: `.from('cars').select('*, car_photos(storage_path)').eq('is_public', true).eq('status', 'available')` — the existing anon-read RLS policy already allows this with no auth.
3. **Card stack widget**: `SwipeDeckScreen` (`ConsumerWidget`) watches `carDeckProvider`, feeds the current page into the swiper package, and on each swipe:
   - **Right** → write the local "interested" decision (see schema-gap note above) + fire `leads` insert (`type` omitted from schema now — use `source: 'swipe_interest'`) with no required name/phone yet (those get collected in a follow-up contact-info modal, or deferred until the dealer follows up).
   - **Left** → write the local "passed" decision only, no `leads` row — `carDeckProvider` filters out already-decided cars client-side (`.where((c) => !locallyDecided.contains(c.id))`), so passed cards don't resurface in the same session.
   - **Up** → push a modal (`showModalBottomSheet`) collecting name/phone, then `leads` insert with `source: 'test_drive_request'`, `car_id` set, mirroring the exact insert shape `docs/api_contracts.md`'s "Creating a Lead" example already documents.
4. **Deep-dive view**: tapping (not swiping) a card pushes a full-screen route with an image carousel over `car_photos` (same `getPublicUrl('vehicle-photos', storage_path)` pattern `InventoryService` already uses) — no new backend work, purely a new screen reading data the deck already fetched.
5. **Distance filtering** ("dealer distance" in the filter matrix) needs the consumer's location (device geolocation permission) and `dealers` to carry a queryable location — `dealers` has `city`/`address` text columns today but no lat/long. If distance filtering is wanted for v1, that's a small migration (`dealers.latitude`/`longitude numeric`, nullable, backfilled manually or via a geocoding call when a dealer's address is set) — flagged here as a dependency, not assumed solved.
6. **Theming**: build this screen against the new target palette from `docs/design.md` §5 (Ambient Blue `#0066FF`, light-first with its own dark mode) via a new `ThemeExtension` scoped to `apps/customer` — don't reuse the dashboard's dark-first `AppPalette`, per `docs/design.md` §1.
