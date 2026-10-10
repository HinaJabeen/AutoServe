# API Query Contracts

## Fetching Available Vehicles (Customer App)

```dart
final response = await SupabaseService.client
    .from('vehicles')
    .select('*, vehicle_images(*)')
    .eq('status', 'available')
    .order('created_at', ascending: false)
    .limit(20);

final vehicles = response.map((v) => VehicleModel.fromJson(v)).toList();
```

## Fetching a Single Vehicle Detail

```dart
final response = await SupabaseService.client
    .from('vehicles')
    .select('*, vehicle_images(*)')
    .eq('id', vehicleId)
    .single();

final vehicle = VehicleModel.fromJson(response);

await SupabaseService.client.rpc('increment_vehicle_views',
  params: {'target_vehicle_id': vehicleId});
```

## Creating a Lead (Inquiry/Test Drive)

```dart
await SupabaseService.client.from('leads').insert({
  'dealership_id': vehicle.dealershipId,
  'vehicle_id': vehicle.id,
  'consumer_id': SupabaseService.currentUser?.id,
  'consumer_name': nameController.text,
  'consumer_phone': phoneController.text,
  'consumer_email': emailController.text,
  'type': 'inquiry', // or 'test_drive'
});
```

## Fetching Dealer's Own Vehicles (Dashboard App)

```dart
final response = await SupabaseService.client
    .from('vehicles')
    .select('*, vehicle_images(*)')
    .eq('dealership_id', currentDealershipId)
    .order('created_at', ascending: false);
```

## Real-time Lead Subscription (Dashboard App)

```dart
SupabaseService.client
    .from('leads')
    .stream(primaryKey: ['id'])
    .eq('dealership_id', currentDealershipId)
    .order('created_at', ascending: false)
    .listen((data) {
      final leads = data.map((l) => LeadModel.fromJson(l)).toList();
    });
```

## Uploading a Vehicle Image

```dart
final path = 'vehicles/$vehicleId/image_${DateTime.now().millisecondsSinceEpoch}.jpg';

await SupabaseService.client.storage
    .from('vehicle-images')
    .uploadBinary(path, imageBytes);

final publicUrl = SupabaseService.client.storage
    .from('vehicle-images')
    .getPublicUrl(path);

await SupabaseService.client.from('vehicle_images').insert({
  'vehicle_id': vehicleId,
  'image_url': publicUrl,
  'is_primary': isFirstImage,
});
```
