-- Vehicle images: public read, authenticated dealers can upload/delete their own
create policy "public_read_vehicle_images"
on storage.objects for select to public
using (bucket_id = 'vehicle-images');

create policy "authenticated_upload_vehicle_images"
on storage.objects for insert to authenticated
with check (bucket_id = 'vehicle-images');

create policy "authenticated_delete_own_vehicle_images"
on storage.objects for delete to authenticated
using (bucket_id = 'vehicle-images' and auth.uid() = owner);

-- Dealer logos
create policy "public_read_dealer_logos"
on storage.objects for select to public
using (bucket_id = 'dealer-logos');

create policy "authenticated_upload_dealer_logos"
on storage.objects for insert to authenticated
with check (bucket_id = 'dealer-logos');

-- QR codes
create policy "public_read_qr_codes"
on storage.objects for select to public
using (bucket_id = 'qr-codes');

create policy "authenticated_upload_qr_codes"
on storage.objects for insert to authenticated
with check (bucket_id = 'qr-codes');