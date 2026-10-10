class DealershipModel {
  final String id;
  final String name;
  final String ownerName;
  final String email;
  final String phone;
  final String city;
  final String? address;
  final String? logoUrl;
  final String status;
  final DateTime createdAt;

  DealershipModel({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.city,
    this.address,
    this.logoUrl,
    required this.status,
    required this.createdAt,
  });

  factory DealershipModel.fromJson(Map<String, dynamic> json) {
    return DealershipModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'AutoServe Dealership',
      ownerName: json['owner_name'] as String? ?? json['owner'] as String? ?? 'Dealership Owner',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? json['contact_phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      address: json['address'] as String?,
      logoUrl: json['logo_url'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_name': ownerName,
      'email': email,
      'phone': phone,
      'city': city,
      'address': address,
      'logo_url': logoUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}