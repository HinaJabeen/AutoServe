// lib/features/dealer_application/models/dealer_application.dart
//
// The signed-in user's own dealership application: the public `dealers` row
// (status, showroom info) plus the private `dealer_verifications` row
// (identity + document paths). See
// backend/.../20261015120000_dealership_verification.sql.

enum ApplicationStatus {
  pending,
  approved,
  rejected,
  suspended;

  static ApplicationStatus fromDb(String? v) => switch (v) {
        'approved' => approved,
        'rejected' => rejected,
        'suspended' => suspended,
        _ => pending,
      };
}

const expectedStockOptions = ['1-5', '5-10', '10-30', '30+'];

const pakistanCities = [
  'Islamabad', 'Rawalpindi', 'Lahore', 'Karachi', 'Faisalabad', 'Multan',
  'Peshawar', 'Quetta', 'Sialkot', 'Gujranwala', 'Hyderabad', 'Abbottabad',
];

const popularBrands = [
  'Toyota', 'Honda', 'Suzuki', 'Hyundai', 'KIA', 'Changan', 'MG', 'Haval',
  'Nissan', 'Mercedes-Benz', 'BMW', 'Audi',
];

class DealerApplication {
  const DealerApplication({
    required this.dealerId,
    required this.status,
    required this.showroomName,
    required this.city,
    this.address,
    this.whatsapp,
    this.businessHours,
    this.showroomPhotoPath,
    this.rejectionReason,
    this.submittedAt,
    this.verifiedAt,
    this.ownerFullName,
    this.ownerCnic,
    this.ownerPhone,
    this.ntnNumber,
    this.cnicFrontPath,
    this.cnicBackPath,
    this.businessDocPath,
    this.inventoryInfo = const {},
  });

  final String dealerId;
  final ApplicationStatus status;
  final String showroomName;
  final String city;
  final String? address;
  final String? whatsapp;
  final String? businessHours;
  final String? showroomPhotoPath;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

  final String? ownerFullName;
  final String? ownerCnic;
  final String? ownerPhone;
  final String? ntnNumber;
  final String? cnicFrontPath;
  final String? cnicBackPath;
  final String? businessDocPath;
  final Map<String, dynamic> inventoryInfo;

  static DateTime? _ts(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  /// [dealer] is a `dealers` row with an embedded `dealer_verifications`
  /// object (or null when that row is missing/unreadable).
  factory DealerApplication.fromRow(Map<String, dynamic> dealer) {
    final rawV = dealer['dealer_verifications'];
    final v = rawV is Map
        ? Map<String, dynamic>.from(rawV)
        : (rawV is List && rawV.isNotEmpty ? Map<String, dynamic>.from(rawV.first as Map) : null);
    final inv = v?['initial_inventory_info'];
    return DealerApplication(
      dealerId: dealer['id'].toString(),
      status: ApplicationStatus.fromDb(dealer['status'] as String?),
      showroomName: dealer['name']?.toString() ?? '',
      city: dealer['city']?.toString() ?? '',
      address: dealer['address'] as String?,
      whatsapp: dealer['contact_phone'] as String?,
      businessHours: dealer['business_hours'] as String?,
      showroomPhotoPath: dealer['showroom_photo_url'] as String?,
      rejectionReason: dealer['rejection_reason'] as String?,
      submittedAt: _ts(dealer['submitted_at'] ?? dealer['created_at']),
      verifiedAt: _ts(dealer['verified_at']),
      ownerFullName: v?['owner_full_name'] as String?,
      ownerCnic: v?['owner_cnic'] as String?,
      ownerPhone: v?['owner_phone'] as String?,
      ntnNumber: v?['ntn_number'] as String?,
      cnicFrontPath: v?['cnic_front_url'] as String?,
      cnicBackPath: v?['cnic_back_url'] as String?,
      businessDocPath: v?['business_doc_url'] as String?,
      inventoryInfo: inv is Map ? Map<String, dynamic>.from(inv) : const {},
    );
  }
}

/// Everything the wizard collects, ready for submit_dealer_application().
class DealerApplicationDraft {
  const DealerApplicationDraft({
    required this.ownerFullName,
    required this.ownerCnic,
    required this.ownerPhone,
    required this.showroomName,
    required this.city,
    required this.address,
    required this.whatsapp,
    required this.businessHours,
    required this.ntnNumber,
    required this.showroomPhotoPath,
    required this.cnicFrontPath,
    required this.cnicBackPath,
    required this.businessDocPath,
    required this.expectedStock,
    required this.primaryMakes,
    this.sampleVehicle,
  });

  final String ownerFullName;
  final String ownerCnic;
  final String ownerPhone;
  final String showroomName;
  final String city;
  final String address;
  final String whatsapp;
  final String businessHours;
  final String ntnNumber;
  final String showroomPhotoPath;
  final String cnicFrontPath;
  final String cnicBackPath;
  final String businessDocPath;
  final String expectedStock;
  final List<String> primaryMakes;

  /// {make, model, year, price}; null when the applicant left it blank.
  final Map<String, Object>? sampleVehicle;

  Map<String, Object?> toRpcParams() => {
        'p_showroom_name': showroomName,
        'p_city': city,
        'p_address': address,
        'p_whatsapp': whatsapp,
        'p_business_hours': businessHours,
        'p_showroom_photo_path': showroomPhotoPath,
        'p_owner_full_name': ownerFullName,
        'p_owner_cnic': ownerCnic,
        'p_owner_phone': ownerPhone,
        'p_ntn_number': ntnNumber,
        'p_cnic_front_path': cnicFrontPath,
        'p_cnic_back_path': cnicBackPath,
        'p_business_doc_path': businessDocPath,
        'p_inventory_info': {
          'expected_stock_size': expectedStock,
          'primary_makes': primaryMakes,
          'sample_vehicle': ?sampleVehicle,
        },
      };
}
