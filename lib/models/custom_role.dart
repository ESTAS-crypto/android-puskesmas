/// Model untuk Role Custom yang bisa dibuat oleh owner/developer.
/// Disimpan di tabel `custom_roles` di Supabase.
class CustomRole {
  final String id;
  final String name;         // Nama role misal "Supervisor"
  final int colorValue;      // Color int (misal 0xFFE040FB)
  final String iconName;     // Nama icon material (misal "supervisor_account")
  final int permissions;     // Bitmask permission
  final String createdBy;    // user_id pembuat
  final DateTime? createdAt;

  const CustomRole({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconName,
    required this.permissions,
    required this.createdBy,
    this.createdAt,
  });

  // ── Permission bits ──────────────────────────────
  static const int permViewAll      = 1 << 0; // Lihat semua laporan
  static const int permExport       = 1 << 1; // Export PDF/DOCX
  static const int permManageUsers  = 1 << 2; // Kelola user
  static const int permDeleteReport = 1 << 3; // Hapus laporan
  static const int permGlobalMode   = 1 << 4; // Akses global report history
  static const int permAdminPanel   = 1 << 5; // Akses admin panel

  bool get canViewAll      => permissions & permViewAll != 0;
  bool get canExport       => permissions & permExport != 0;
  bool get canManageUsers  => permissions & permManageUsers != 0;
  bool get canDeleteReport => permissions & permDeleteReport != 0;
  bool get canGlobalMode   => permissions & permGlobalMode != 0;
  bool get canAdminPanel   => permissions & permAdminPanel != 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorValue,
        'icon': iconName,
        'permissions': permissions,
        'created_by': createdBy,
      };

  factory CustomRole.fromMap(Map<String, dynamic> map) {
    return CustomRole(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      colorValue: _parseInt(map['color'] ?? map['color_value'], 0xFFE040FB),
      iconName: map['icon'] as String? ?? map['icon_name'] as String? ?? 'person_rounded',
      permissions: _parseInt(map['permissions'], 0),
      createdBy: map['created_by'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  CustomRole copyWith({
    String? name,
    int? colorValue,
    String? iconName,
    int? permissions,
  }) {
    return CustomRole(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      permissions: permissions ?? this.permissions,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

int _parseInt(dynamic val, int defaultValue) {
  if (val == null) return defaultValue;
  if (val is num) return val.toInt();
  if (val is String) {
    final parsed = int.tryParse(val);
    if (parsed != null) return parsed;
    if (val.toLowerCase().startsWith('0x')) {
      return int.tryParse(val.substring(2), radix: 16) ?? defaultValue;
    }
    return double.tryParse(val)?.toInt() ?? defaultValue;
  }
  return defaultValue;
}
