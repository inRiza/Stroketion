class LinkedPatient {
  const LinkedPatient({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.linkId,
    this.relationship,
  });

  final String id;
  final String? fullName;
  final String email;
  final String? phone;
  final String linkId;
  final String? relationship;

  factory LinkedPatient.fromJson(Map<String, dynamic> json) {
    return LinkedPatient(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      linkId: json['link_id'] as String,
      relationship: json['relationship'] as String?,
    );
  }
}

class LinkedCaregiver {
  const LinkedCaregiver({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.linkId,
    required this.status,
    this.relationship,
    this.initiatedBy,
  });

  final String id;
  final String? fullName;
  final String email;
  final String? phone;
  final String linkId;
  final String status;
  final String? relationship;
  final String? initiatedBy;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get needsPatientApproval => isPending && initiatedBy == 'caregiver';
  bool get waitingCaregiverApproval => isPending && initiatedBy == 'patient';

  factory LinkedCaregiver.fromJson(Map<String, dynamic> json) {
    return LinkedCaregiver(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      linkId: json['link_id'] as String,
      status: json['status'] as String,
      relationship: json['relationship'] as String?,
      initiatedBy: json['initiated_by'] as String?,
    );
  }
}

class CaregiverLookup {
  const CaregiverLookup({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
  });

  final String id;
  final String? fullName;
  final String? phone;
  final String email;

  factory CaregiverLookup.fromJson(Map<String, dynamic> json) {
    return CaregiverLookup(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String,
    );
  }
}

class PendingNotification {
  const PendingNotification({
    required this.linkId,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.relationship,
    required this.createdAt,
  });

  final String linkId;
  final String patientId;
  final String? patientName;
  final String? patientPhone;
  final String? relationship;
  final String createdAt;

  factory PendingNotification.fromJson(Map<String, dynamic> json) {
    return PendingNotification(
      linkId: json['link_id'] as String,
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String?,
      patientPhone: json['patient_phone'] as String?,
      relationship: json['relationship'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String role;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
    );
  }
}
