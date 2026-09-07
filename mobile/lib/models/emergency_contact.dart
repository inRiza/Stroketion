class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.type,
    required this.priority,
    this.source = 'manual',
    this.caregiverId,
  });

  final String id;
  final String name;
  final String phone;
  final String type;
  final int priority;
  final String source;
  final String? caregiverId;

  bool get isCaregiver => type == 'caregiver';
  bool get isSos => type == 'sos';

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? type,
    int? priority,
    String? source,
    String? caregiverId,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      source: source ?? this.source,
      caregiverId: caregiverId ?? this.caregiverId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'type': type,
        'priority': priority,
        'source': source,
        if (caregiverId != null) 'caregiver_id': caregiverId,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      type: json['type'] as String? ?? 'sos',
      priority: json['priority'] as int? ?? 1,
      source: json['source'] as String? ?? 'manual',
      caregiverId: json['caregiver_id'] as String?,
    );
  }
}
