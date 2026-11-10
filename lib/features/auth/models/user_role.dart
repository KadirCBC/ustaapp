enum UserRole {
  musteri,
  usta;

  String toDbValue() {
    switch (this) {
      case UserRole.musteri:
        return 'musteri';
      case UserRole.usta:
        return 'usta';
    }
  }

  static UserRole? fromDbValue(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'usta':
        return UserRole.usta;
      case 'musteri':
        return UserRole.musteri;
      default:
        return null;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.musteri:
        return 'Müşteri';
      case UserRole.usta:
        return 'Usta';
    }
  }
}
