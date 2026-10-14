# API Query Contracts

These match the live schema (`dealers`/`dealer_staff`/`cars`/`car_photos`/
`leads`/...) and the actual queries used by `apps/dashboard`. An earlier
version of this document showed `vehicles`/`vehicle_images`/generic-`users`
queries from a schema that was never live — see `docs/architecture.md` §4.

## Fetching a Dealer's Own Inventory (Dashboard App)

```dart
final response = await SupabaseService.client
    .from('cars')
    .select('*, car_photos(storage_path)')
    .eq('dealer_id', currentDealerId)
    .order('created_at', ascending: false)
    .range(offset, offset + limit - 1);

final cars = response.map((row) {
  final photos = (row['car_photos'] as List)
      .map((p) => SupabaseService.client.storage
          .from('vehicle-photos')
          .getPublicUrl(p['storage_path'] as String))
      .toList();
  return CarModel.fromJson({...row, 'photo_urls': photos});
}).toList();
```

See `InventoryService.fetchPage` (`apps/dashboard/lib/features/inventory/services/inventory_service.dart`) for the real implementation, including search/status filtering and pagination.

## Creating a Car

```dart
await SupabaseService.client.from('cars').insert({
  'dealer_id': currentDealerId,
  'make': make,
  'model': model,
  'year': year,
  'price': price,
  'status': 'available',
  // ...other columns; see CarModel.toInsertJson()
});
```

## Uploading a Vehicle Photo

```dart
final bytes = await file.readAsBytes(); // XFile — Web-safe, no dart:io
final path = '$dealerId/$carId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

await SupabaseService.client.storage
    .from('vehicle-photos')
    .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: file.mimeType));

await SupabaseService.client.from('car_photos').insert({
  'car_id': carId,
  'storage_path': path,
  'is_primary': isFirstPhoto,
  'display_order': index,
});
```

See `VehicleStorageService.uploadAll` for the real implementation.

## Creating a Lead (Inquiry/Test Drive)

```dart
await SupabaseService.client.from('leads').insert({
  'dealer_id': dealerId,
  'car_id': carId, // nullable — general inquiry
  'customer_name': nameController.text,
  'customer_phone': phoneController.text,
  'source': 'online', // or 'walk_in'
  'stage': 'new',
});
```

This insert is allowed for both `anon` and `authenticated` callers — the public portal has no account to require (see `docs/security.md` §2).

## Real-time Lead Subscription (Dashboard App)

```dart
SupabaseService.client
    .from('leads')
    .stream(primaryKey: ['id'])
    .eq('dealer_id', currentDealerId)
    .order('created_at', ascending: false)
    .listen((rows) {
      final leads = rows.map((r) => LeadModel.fromJson({
        'id': r['id'],
        'dealership_id': r['dealer_id'],
        'vehicle_id': r['car_id'],
        'consumer_name': r['customer_name'],
        'consumer_phone': r['customer_phone'],
        'status': r['stage'],
        'notes': r['notes'],
        'created_at': r['created_at'],
      })).toList();
    });
```

`LeadModel` (in `shared/`) still uses the old field names (`dealershipId`, `vehicleId`, `consumerName`, `status`) — the mapping above from DB columns to model fields happens in `lead_provider.dart`/`overview_provider.dart`. Don't call `LeadModel.fromJson` directly on a raw `leads` row; it won't line up.

## Updating a Lead's Stage

```dart
await SupabaseService.client
    .from('leads')
    .update({'stage': newStage})
    .eq('id', leadId);
```
