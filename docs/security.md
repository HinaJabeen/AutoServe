# AutoServe — Security Model

Security is implemented almost entirely in Postgres (Supabase), not in Flutter. The client is untrusted by design — assume any user can inspect network traffic, modify a request, or run their own queries against the anon/authenticated API keys embedded in the app. The database must refuse anything the client shouldn't be able to do, regardless of what the UI allows.

## 1. Authentication

- Supabase Auth (`auth.users`) is the identity provider for dealership staff, superadmins, and — since `backend/supabase/supabase/migrations/20261013160000_customer_profiles.sql` — consumers: `apps/customer` requires email/password sign-in, and each account has a `profiles` row (name, phone, mirrored role). Confirmed against the live schema: `dealer_staff`/`cars`/`leads`/etc. are the real tables; an earlier draft of this document and of the migrations described a `vehicles`/generic-`users` schema that was never live, and that has now been fully replaced in `backend/supabase/supabase/migrations/`.
- Staff accounts are provisioned explicitly into `dealer_staff` (tied to a `dealer_id` + `auth.users.id`), and superadmins into `admin_users` — a signup alone never grants either. Self-serve signup exists only for consumers: `handle_new_user()` (trigger on `auth.users` insert) creates a `profiles` row with `role = 'customer'`, copying only `full_name`/`phone` from the client-supplied signup metadata and **never** a role. `profiles.role` is a mirror of `dealer_staff`/`admin_users` maintained by `sync_profile_role()`; clients can't write it (column-level grants), and no RLS policy trusts it — tenant scope still comes from `dealer_staff` only. `apps/customer`'s `AuthNotifier` (`features/auth/providers/auth_providers.dart`) reads it after sign-in and signs out any account that isn't `customer` (dealers/admins are sent back to `/login` with a message); a missing profile row or unrecognised role is treated as not-a-customer.
- `apps/dashboard`'s `AuthNotifier` (`features/providers/auth_provider.dart`) resolves a signed-in user's role by querying `dealer_staff` first, falling back to a legacy `users` table lookup — **that fallback branch queries a table that does not exist in the live schema** (see `docs/architecture.md` §4/§5); treat it as dead code to remove or to repoint at `admin_users`, not as a second valid path. It explicitly handles: deactivated staff (`status == 'deactivated'`), suspended dealers, unregistered accounts, and a forced first-login password change (`requires_password_change`). Any new role-resolution logic must preserve this "deny by default, verify every condition before granting `authenticated` app state" structure — do not short-circuit to "authenticated" on the mere presence of a session.
- **Role-based routing** (login → superadmin panel / dealer CRM / consumer app) must resolve the superadmin branch from **`admin_users`**, never a `public.users`/generic-`users` table — product/spec language describing routing as "if role in `public.users` == admin" is describing the old, retired schema; implement against `admin_users` instead. Product terms "dealer owner" and "sales rep" map onto `dealer_staff.role`'s two real values, `owner` and `staff` — there is no third `sales_rep` enum value to add; don't let a spec's naming drift into inventing a role the schema doesn't have.
- Password recovery is handled via Supabase's `AuthChangeEvent.passwordRecovery` event, routed by `go_router`'s `refreshListenable` to a dedicated update-password screen — don't build a custom reset-token flow; use Supabase's built-in recovery link mechanism.
- On sign-out, invalidate every per-dealer cached provider **before** calling `auth.signOut()` (see `docs/design.md` §3) — this prevents a stale Riverpod cache from serving the previous tenant's data to whoever logs in next on the same device/session.

## 2. Row Level Security (RLS) — tenant isolation

Every table that holds tenant data has `alter table ... enable row level security;` (`backend/supabase/supabase/migrations/20260630062836_rls_policies.sql`). **RLS is the actual security boundary for multi-tenancy — not application code.** The standing policies, against the confirmed live schema:

| Table | Who | Can | Rule |
|---|---|---|---|
| `dealers` | active staff | select own | `id in (select dealer_id from dealer_staff where user_id = auth.uid() and status = 'active')` |
| `dealers` | active `owner` staff | update own | same, plus `role = 'owner'` |
| `dealers` | `admin_users` member | all | `auth.uid() in (select id from admin_users)` |
| `dealers` | `anon` / `authenticated` | select | only `status = 'approved'` (public listing attribution; the `authenticated` half exists so signed-in customers see the same rows anon visitors do) |
| `profiles` | self | select own row | `id = auth.uid()` |
| `profiles` | self | update own row, `full_name`/`phone` only | `id = auth.uid()`; `role`/`id` are not granted for update, and there is no client insert/delete |
| `dealer_staff` | self | select/update own row | `user_id = auth.uid()` |
| `dealer_staff` | active `owner` staff | manage staff in own dealer | `dealer_id in (select dealer_id from dealer_staff where user_id = auth.uid() and role = 'owner' and status = 'active')` |
| `admin_users` | self | select own row | `id = auth.uid()` |
| `admin_users` | `admin_users` member | manage all | `auth.uid() in (select id from admin_users)` |
| `cars` | active staff of the owning dealer | full CRUD | `dealer_id in (select dealer_id from dealer_staff where user_id = auth.uid() and status = 'active')` |
| `cars` | `authenticated` / `anon` | select | only `is_public = true and status = 'available'` |
| `car_photos` | active staff of the car's dealer | full CRUD | join through `cars` → `dealer_staff` on `dealer_id` |
| `car_photos` | `anon` | select | only for cars that are `is_public`/`available` |
| `car_photos` | `authenticated` | select | `true` — any signed-in staff can view any car's photos |
| `car_audit_logs` | active staff of the car's dealer | select | join through `cars` → `dealer_staff` |
| `leads` | active staff of the owning dealer | full CRUD | `dealer_id in (select dealer_id from dealer_staff where user_id = auth.uid() and status = 'active')` |
| `leads` | `anon` / `authenticated` | insert | `true` — the public portal has no account to gate on; lead capture is intentionally open-insert |
| `lead_activity` | active staff of the lead's dealer | full CRUD | join through `leads` → `dealer_staff` |
| `notifications` | the target user | select/update own | `user_id = auth.uid()` |
| `staff_invites` | active `owner` staff of the dealer | full CRUD | `dealer_id in (select dealer_id from dealer_staff where user_id = auth.uid() and role = 'owner' and status = 'active')` |
| `admin_activity` / `ai_usage_log` | `admin_users` member / owning dealer's staff | all / select | see migration for exact clauses |

**Rules to follow when writing new SQL or new queries:**
1. **Every new tenant-scoped table must enable RLS and get an explicit policy before it ships** — a table with RLS enabled and no policy denies all access by default, which is the safe failure mode; a table with RLS *disabled* is an open table regardless of what the app's queries assume.
2. **Never write a policy that trusts a client-supplied `dealer_id`.** Every policy above derives the dealer from `auth.uid()` via a subquery into `dealer_staff` — the caller cannot claim a different dealer by passing a different ID in the request body. Follow this subquery pattern for any new table, and always add `and status = 'active'` so a deactivated staff account's session loses access immediately rather than at next token refresh.
3. **`anon` access is opt-in and narrow**, with one deliberate exception: `leads` accepts anonymous inserts, because the public portal has no account to require (see §1). Every other `anon` policy is read-only, scoped to already-public data (`approved` dealers, public/available cars, their photos). Do not widen `anon` write access elsewhere without a specific product reason.
4. **Before writing any SQL migration that touches an existing table, check its current RLS policies in the relevant migration file first** — adding a column or a new access path without re-checking existing `using`/`with check` clauses is how tenant isolation quietly breaks.
5. **There is no schema drift left to route around.** `profiles`/`dealers`/`dealer_staff`/`cars`/`car_photos`/`car_audit_logs`/`leads`/`lead_activity`/`notifications`/`staff_invites`/`admin_users`/`admin_activity`/`ai_usage_log` are the confirmed live tables and now match the migrations in this repo. If you encounter Dart code referencing a `users` or `vehicles`-shaped table/column that doesn't fit this list, that's legacy/orphaned code (see `docs/architecture.md` §5) — fix the code to match the live schema rather than writing a migration to match the code.

## 3. Security-definer triggers (controlled privilege escalation)

Postgres trigger functions run with elevated rights (`security definer set search_path = public`) so an unprivileged caller can trigger a narrow, specific side effect without being granted broad table permissions:

- **`notify_dealer_on_new_lead()`** (trigger on `leads` insert) — looks up the dealer's active `owner` staff member and inserts a `notifications` row, so an anonymous lead submission can notify the dealer without the caller ever having insert rights on `notifications`.
- **`log_car_update()`** (trigger on `cars` update) — writes a `car_audit_logs` row when `status`/`price`/`mileage` changes, using `auth.uid()` as the actor, so staff don't need direct insert rights on the audit table.
- **`handle_new_user()`** (trigger on `auth.users` insert) — inserts the new user's `profiles` row. Signup metadata is untrusted input: name/phone are truncated to the column limits (so a hostile payload can't make the insert fail and block signups) and the role is hard-coded to `customer`.
- **`sync_profile_role()`** (triggers on `dealer_staff` and `admin_users` insert/delete) — recomputes `profiles.role` for the affected user from those two tables, so clients never need (or get) write access to the column.

The earlier `increment_vehicle_views(target_vehicle_id uuid)` RPC has been removed: the live `cars` table has no `views_count` column, and no Dart code calls it — it belonged to the old `vehicles` schema. Re-introduce it (with the column) only if the customer portal actually needs view tracking.

**When adding a new `security definer` function/trigger**: keep its scope as narrow as the two above (one specific, auditable side effect), always set `search_path = public` explicitly (prevents search-path hijacking), and never let it accept a caller-supplied user/dealer ID that bypasses `auth.uid()` — derive identity from the session, exactly as `notify_dealer_on_new_lead` derives the dealer from the lead's own `dealer_id` rather than a passed-in parameter.

## 4. Storage bucket policies

Two buckets exist (`backend/supabase/supabase/migrations/20260630063208_storage_policies.sql`): `vehicle-photos` and `dealer-logos`. Pattern for both: **public read, authenticated write**.

- `select` is granted `to public` with `using (bucket_id = '<bucket>')` — anyone can view these assets (they're meant to be publicly visible on listings), no auth required.
- `insert` is granted `to authenticated` with `with check (bucket_id = '<bucket>')` — any authenticated user can upload into these buckets. **Note this is coarser than table-level RLS**: it does not check `dealer_id` or ownership at upload time, meaning any authenticated staff account can technically upload into any other dealer's path prefix within a bucket. The app-level convention (`VehicleStorageService` paths as `$dealerId/$carId/...`) is what keeps uploads organized per-dealer, but it is **not enforced by the storage policy itself**.
- `delete` on `vehicle-photos` is scoped with `auth.uid() = owner` (the uploader can delete their own objects) — `dealer-logos` currently has no delete policy at all, meaning no one can delete those objects via the client API as it stands.
- A third bucket, `qr-codes`, existed in the old migrations but has been dropped: no Dart code uploads a QR image to storage — QR codes are rendered in-memory (`QrPainter`/`CustomPainter`) and embedded directly into generated PDFs or drawn as widgets, never persisted. Re-add it only if that changes.
- **Bucket-name bug fixed in this pass**: `VehicleStorageService` previously uploaded to a bucket (`vehicles`) that matched neither the storage policies (`vehicle-images`) nor the bucket `InventoryService` read photo URLs from (`vehicle-photos`) — so uploaded photos never displayed. Both sides now agree on `vehicle-photos`, and uploads write a `car_photos` row instead of a `cars.specs.images` JSON entry the read path never looked at.

**If asked to harden storage further**: tighten `insert`/`delete` policies to check the path prefix against the caller's `dealer_id` (e.g. `(storage.foldername(name))[1] = (select dealer_id::text from dealer_staff where user_id = auth.uid())`) rather than relying on app convention alone. Treat the current "authenticated write, app convention keeps paths tidy" setup as acceptable for the current stage of the project, not as a pattern to defend if asked to improve it.

## 5. Secrets

`.env` files (Supabase URL + anon key) live per-app (`apps/dashboard/.env`, `apps/customer/.env`) and must never be committed — confirm `.gitignore` covers them before adding new env-dependent config. The anon key is safe to ship in a client bundle *only because* RLS is doing the real access control; it is not a secret in the traditional sense, but it is also not a substitute for RLS on any table.
