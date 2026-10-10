# Module B Integration Checklist

Your app has two separate folder structures that **aren't connected**. Here's how to wire them together.

## 1. **Update your pubspec.yaml**

Add these dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  go_router: ^13.0.0
  supabase_flutter: ^1.10.0
  flutter_dotenv: ^5.1.0
  image_picker: ^1.1.2
  flutter_image_compress: ^2.3.0
  http: ^1.2.0
  csv: ^6.0.0
  file_picker: ^8.0.0
  pdf: ^3.11.0
  printing: ^5.13.0
  qr_flutter: ^4.1.0
```

Then run: `flutter pub get`

## 2. **Copy Module B files to your project**

From `/mnt/user-data/outputs/`, copy:

```
lib/features/inventory/              → apps/dashboard/lib/features/inventory/
lib/core/router/app_router.dart      → apps/dashboard/lib/core/router/app_router.dart
lib/core/theme/app_theme.dart        → apps/dashboard/lib/core/theme/app_theme.dart
lib/main.dart                        → apps/dashboard/lib/main.dart
sql/0007_module_b_inventory_production.sql → database/migrations/
```

## 3. **Create required directories** (if they don't exist)

```bash
mkdir -p apps/dashboard/lib/core/router
mkdir -p apps/dashboard/lib/core/theme
mkdir -p apps/dashboard/lib/features/inventory/models
mkdir -p apps/dashboard/lib/features/inventory/services
mkdir -p apps/dashboard/lib/features/inventory/providers
mkdir -p apps/dashboard/lib/features/inventory/presentation/widgets
```

## 4. **Update your dashboard_shell.dart**

Replace your current `lib/layout/dashboard_shell.dart` with the version from `lib/layout/dashboard_shell_updated.dart` (in outputs).

This changes:
- Imports GoRouter instead of hardcoded navigation
- Uses real Riverpod providers
- Wires the Inventory button to the new `InventoryGridScreen` (Module B)

## 5. **Update your overview_provider.dart**

Ensure it imports **real** model classes, not mock data:

```dart
import 'package:shared/shared.dart';  // Real models
import 'package:supabase_flutter/supabase_flutter.dart';
```

The file I saw earlier had mock data that bypassed the database — that's why nothing changed. The new providers in Module B use **actual** Supabase queries.

## 6. **Update your auth_provider.dart**

Ensure it properly initializes auth and sets `dealershipId`:

```dart
// Key lines to check:
final dealerId = ref.watch(currentDealershipIdProvider);  // Must be populated

// In _resolveAuthenticatedUser(), ensure:
state = AuthState(
  status: AuthStatus.authenticated,
  user: user,
  dealershipId: user.dealershipId,  // ← This must be set
);
```

## 7. **Apply the SQL migration**

Run in Supabase Studio → SQL Editor:

```sql
-- Paste the contents of:
-- sql/0007_module_b_inventory_production.sql
```

This adds:
- New columns to `cars` table
- `car_audit_logs` table with trigger
- Updated storage RLS for `vehicle-photos` bucket

## 8. **Create .env file** (if not already present)

In `apps/dashboard/`, create `.env`:

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Never commit `.env` — add to `.gitignore`.

## 9. **Wire the CSV import button**

In `lib/features/inventory/presentation/inventory_grid_screen.dart`, line ~81:

**Change:**
```dart
onPressed: () {}, // wire to CsvImportDialog / file picker in app shell
```

**To:**
```dart
onPressed: () => showDialog(context: context, builder: (_) => const CsvImportDialog()),
```

## 10. **Test the app**

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

**Expected behavior:**
1. Login screen appears
2. After login, you're redirected to Overview (dashboard metrics)
3. Click "Inventory" in the sidebar → **New grid appears with all Module B features:**
   - Paginated vehicle grid (infinite scroll)
   - Search by make/model
   - Status filter dropdowns
   - Sort by price/date
   - Checkboxes for bulk selection
   - "Days on lot" badge
   - Add/Edit/Delete buttons
   - VIN decoder in the add form
   - Profit margin visibility (staff-only)
   - CSV bulk import

## 11. **Troubleshooting**

**If you still see the old inventory list:**
- Verify `dashboard_shell.dart` was replaced (not merged)
- Check that imports point to `InventoryGridScreen`, not `InventoryListScreen`
- Clear build cache: `flutter clean && flutter pub get`

**If you get "InventoryGridScreen not found":**
- Verify the file was copied to `lib/features/inventory/presentation/inventory_grid_screen.dart`
- Run `flutter pub get`
- Restart your IDE

**If login doesn't work:**
- Check `.env` file has correct Supabase URL/key
- Verify `auth_provider.dart` initializes properly
- Check Supabase credentials in Studio

**If grid shows "No vehicles" but you have data:**
- Check `dealer_id` is properly set in auth state
- Verify RLS policies allow your user to read `cars` table
- Check browser dev console for API errors

---

**Summary:** You had the **components** but not the **app structure**. The new `main.dart`, `app_router.dart`, and `dashboard_shell_updated.dart` **wire everything together**. Follow steps 1–10 above and Module B will be live.
