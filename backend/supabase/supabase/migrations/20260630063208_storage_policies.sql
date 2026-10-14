-- ============================================
-- STORAGE POLICIES — reconciled against live schema
-- ============================================
-- Supersedes the earlier version of this migration.
--
-- Bucket names corrected to match what the Flutter code actually uses:
--   - 'vehicle-photos' (was two different, inconsistent names —
--     'vehicle-images' here and 'vehicles' in vehicle_storage_service.dart —
--     neither matched the 'vehicle-photos' bucket InventoryService read
--     from; see docs/architecture.md §4 and the vehicle_storage_service.dart
--     fix in this same change).
--   - 'dealer-logos' kept (dealers.logo_url is read by dashboard_shell.dart).
--   - 'qr-codes' dropped: no Dart code uploads a QR code image to storage.
--     QR codes are rendered in-memory (CustomPainter / QrPainter) and
--     embedded directly into generated PDFs or widgets — never persisted
--     to a bucket. Re-add this bucket's policies if that changes.

-- Vehicle photos: public read, authenticated dealers can upload/delete their own
create policy "public_read_vehicle_photos"
on storage.objects for select to public
using (bucket_id = 'vehicle-photos');

create policy "authenticated_upload_vehicle_photos"
on storage.objects for insert to authenticated
with check (bucket_id = 'vehicle-photos');

create policy "authenticated_delete_own_vehicle_photos"
on storage.objects for delete to authenticated
using (bucket_id = 'vehicle-photos' and auth.uid() = owner);

-- Dealer logos
create policy "public_read_dealer_logos"
on storage.objects for select to public
using (bucket_id = 'dealer-logos');

create policy "authenticated_upload_dealer_logos"
on storage.objects for insert to authenticated
with check (bucket_id = 'dealer-logos');
