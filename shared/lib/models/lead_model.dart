class LeadModel {
  final String id;
  final String dealershipId;
  final String? vehicleId;
  final String? consumerId;
  final String consumerName;
  final String? consumerPhone;
  final String? consumerEmail;
  final String type;
  final String status;
  final String? notes;
  final DateTime createdAt;

  LeadModel({
    required this.id,
    required this.dealershipId,
    this.vehicleId,
    this.consumerId,
    required this.consumerName,
    this.consumerPhone,
    this.consumerEmail,
    required this.type,
    this.status = 'new',
    this.notes,
    required this.createdAt,
  });

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: json['id'] as String,
      dealershipId: json['dealership_id'] as String,
      vehicleId: json['vehicle_id'] as String?,
      consumerId: json['consumer_id'] as String?,
      consumerName: json['consumer_name'] as String,
      consumerPhone: json['consumer_phone'] as String?,
      consumerEmail: json['consumer_email'] as String?,
      type: json['type'] as String,
      status: json['status'] as String? ?? 'new',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dealership_id': dealershipId,
      'vehicle_id': vehicleId,
      'consumer_id': consumerId,
      'consumer_name': consumerName,
      'consumer_phone': consumerPhone,
      'consumer_email': consumerEmail,
      'type': type,
      'status': status,
      'notes': notes,
    };
  }
}
