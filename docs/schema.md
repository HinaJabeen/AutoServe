# Database Schema Explained

This describes the confirmed live Supabase schema. An earlier version of this
document described a `vehicles`/`vehicle_images`/generic-`users` schema that
was never actually live — see `docs/architecture.md` §4 for why, and §5 for
which app code still (incorrectly) assumes that old shape.

## dealers

One row per dealership (car showroom). It has a `status` field:

- `pending` = waiting for admin approval
- `approved` = can use the platform
- `suspended` = blocked

## dealer_staff

Every staff member who logs into the dashboard — owners and salespeople.
Links a `dealer_id` to a Supabase Auth `user_id`. `role` is `owner` or
`staff`; `status` is `active` or `deactivated`. `requires_password_change`
forces a first-login password reset (e.g. after accepting a staff invite).

There is no generic `users` table. Consumers have their own table,
`profiles` (below).

## profiles

One row per Supabase Auth user (`id` = `auth.users.id`), created
automatically by the `handle_new_user()` trigger on signup. Holds the
`full_name` and `phone` a customer enters when signing up in `apps/customer`,
plus a `role`: `customer`, `dealer`, or `admin`.

`role` is **not** something a user or the app sets. It is a read-only mirror
of the real role tables — `admin` if the user has an `admin_users` row,
`dealer` if they have a `dealer_staff` row, otherwise `customer` — kept in
sync by the `sync_profile_role()` trigger. The customer app reads it to turn
staff accounts away at login; no RLS policy relies on it. A user can read and
edit only their own row, and only the `full_name`/`phone` columns.

## cars

One row per vehicle listed by a dealer. `status` can be `available`,
`reserved`, `sold`, or `inactive`. Only `is_public = true` **and**
`status = 'available'` cars are shown to anonymous/public visitors.
`specs` is a flexible `jsonb` column for attributes that don't need their
own typed column; `features` is a plain text array.

## car_photos

Multiple photos per car. `storage_path` is the path inside the
`vehicle-photos` Storage bucket (not a full URL — build the public URL with
`storage.from('vehicle-photos').getPublicUrl(storage_path)`, same as
`InventoryService._withPhotoUrls`). `is_primary` marks the main thumbnail;
`display_order` controls gallery ordering.

## car_audit_logs

History of changes to a car (status/price/mileage edits), written by the
`log_car_update()` trigger — not inserted directly by the app.

## leads

Created when a customer submits an inquiry or books a test drive, via the
(not yet built) customer portal, or logged manually by staff. `car_id` is
nullable (a general inquiry with no specific vehicle). `stage` tracks the
sales pipeline: `new` → `contacted` → `test_drive_scheduled` →
`negotiating` → `closed_won`/`closed_lost`. This is what shows up in the
dealer's lead inbox (Kanban board).

## lead_activity

Interaction history/notes logged against a lead over time (calls, visits,
offers) — not yet consumed by any current dashboard screen.

## notifications

Auto-created by the `notify_dealer_on_new_lead()` trigger whenever a new
lead comes in. This powers the real-time alert on the dealer dashboard.

## staff_invites

Pending invitations for a dealer to onboard a new staff member. Not yet
written to by any current dashboard screen — the accept-invite flow
(`accept_invite_screen.dart`) assumes the invited user's `dealer_staff` row
already exists and only handles setting a permanent password.

## admin_users

Superadmin/platform-level accounts, separate from `dealer_staff`.

## admin_activity

Audit trail of actions taken by superadmins.

## ai_usage_log

Tracking for AI/automation operations (e.g. VIN decoding via
`VinDecoderService`) — not yet written to by any current dashboard code.
