class SosAlert {
  const SosAlert({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String message;
  final String createdAt;

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    return SosAlert(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String? ?? 'Pasien',
      message: json['message'] as String,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
