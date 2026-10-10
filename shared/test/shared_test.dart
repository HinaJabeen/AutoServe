import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('VehicleModel parses image data and formats price', () {
    final vehicle = VehicleModel.fromJson({
      'id': 'vehicle-1',
      'dealership_id': 'dealership-1',
      'make': 'Toyota',
      'model': 'Corolla',
      'year': 2022,
      'mileage': 18000,
      'price': 6800000,
      'condition': 'used',
      'fuel_type': 'petrol',
      'transmission': 'automatic',
      'status': 'available',
      'created_at': '2024-01-01T00:00:00.000Z',
      'vehicle_images': [
        {
          'id': 'img-1',
          'vehicle_id': 'vehicle-1',
          'image_url': 'https://example.com/car.jpg',
          'is_primary': true,
          'display_order': 0,
        },
      ],
    });

    expect(vehicle.displayTitle, '2022 Toyota Corolla');
    expect(vehicle.primaryImageUrl, 'https://example.com/car.jpg');
    expect(vehicle.formattedPrice, 'PKR 6,800,000');
  });
}
