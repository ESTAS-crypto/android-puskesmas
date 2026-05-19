import 'dart:convert';

class UserSession {
  final String userId;
  final String email;
  final String nama;
  final String puskesmas;
  final String bulan;
  final String tahun;
  final String role;

  UserSession({
    this.userId = '',
    this.email = '',
    required this.nama,
    required this.puskesmas,
    required this.bulan,
    required this.tahun,
    this.role = 'user',
  });

  // ── Role hierarchy: owner > developer > admin > user ──
  static const Map<String, int> _roleLevels = {
    'user': 0,
    'admin': 1,
    'developer': 2,
    'owner': 3,
  };

  int get roleLevel => _roleLevels[role] ?? 0;

  /// True jika role adalah admin, developer, atau owner (dapat akses Admin Panel).
  bool get isAdmin => roleLevel >= 1;

  /// True hanya untuk developer atau owner.
  bool get isDeveloper => roleLevel >= 2;

  /// True hanya untuk owner.
  bool get isOwner => role == 'owner';

  /// True jika boleh mengubah role user lain (developer/owner saja).
  bool get canManageRoles => roleLevel >= 2;

  /// Cek apakah session ini boleh memodifikasi target berdasarkan roleLevel.
  /// Rule: hanya boleh memodifikasi role yang LEBIH RENDAH dari diri sendiri.
  bool canModifyRole(String targetRole) {
    if (!canManageRoles) return false;
    final targetLevel = _roleLevels[targetRole] ?? 0;
    return roleLevel > targetLevel;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'nama': nama,
      'puskesmas': puskesmas,
      'bulan': bulan,
      'tahun': tahun,
      'role': role,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nama: json['nama'] as String,
      puskesmas: json['puskesmas'] as String,
      bulan: json['bulan'] as String,
      tahun: json['tahun'] as String,
      role: json['role'] as String? ?? 'user',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static UserSession fromJsonString(String jsonStr) =>
      UserSession.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  String get bulanTahun => '$bulan $tahun';

  /// Buat salinan UserSession dengan perubahan tertentu
  UserSession copyWith({
    String? userId,
    String? email,
    String? nama,
    String? puskesmas,
    String? bulan,
    String? tahun,
    String? role,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      nama: nama ?? this.nama,
      puskesmas: puskesmas ?? this.puskesmas,
      bulan: bulan ?? this.bulan,
      tahun: tahun ?? this.tahun,
      role: role ?? this.role,
    );
  }
}
