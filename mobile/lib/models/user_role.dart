enum UserRole {
  patient,
  caregiver;

  String get label {
    switch (this) {
      case UserRole.patient:
        return 'Pasien';
      case UserRole.caregiver:
        return 'Caregiver';
    }
  }

  String get apiValue {
    switch (this) {
      case UserRole.patient:
        return 'patient';
      case UserRole.caregiver:
        return 'caregiver';
    }
  }

  String get homeRoute {
    switch (this) {
      case UserRole.patient:
        return '/home/patient';
      case UserRole.caregiver:
        return '/home/caregiver';
    }
  }

  static UserRole fromApiValue(String value) {
    return value == 'caregiver' ? UserRole.caregiver : UserRole.patient;
  }
}
