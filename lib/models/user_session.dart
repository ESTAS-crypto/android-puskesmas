import 'dart:convert';
import 'custom_role.dart';

class UserSession {
  final String userId;
  final String email;
  final String nama;
  final String puskesmas;
  final String bulan;
  final String tahun;
  final String role;

  /// Custom role yang di-assign ke user ini (nullable).
  /// Jika tidak null, permission bits dari custom role ini
  /// digunakan BERSAMA role bawaan untuk menentukan akses.
  final CustomRole? customRole;

  UserSession({
    this.userId = '',
    this.email = '',
    required this.nama,
    required this.puskesmas,
    required this.bulan,
    required this.tahun,
    this.role = 'user',
    this.customRole,
  });

  // ── Role hierarchy: owner > developer > admin > user ──
  static const Map<String, int> _roleLevels = {
    'user': 0,
    'admin': 1,
    'developer': 2,
    'owner': 3,
  };

  int get roleLevel => _roleLevels[role] ?? 0;

  /// True jika role bawaan adalah admin, developer, atau owner.
  /// ATAU jika custom role memiliki bit permAdminPanel.
  bool get isAdmin => roleLevel >= 1 || (customRole?.canAdminPanel ?? false);

  /// True hanya untuk developer atau owner (built-in).
  bool get isDeveloper => roleLevel >= 2;

  /// True hanya untuk owner (built-in).
  bool get isOwner => role == 'owner';

  /// True jika boleh mengubah role user lain (developer/owner saja).
  bool get canManageRoles => roleLevel >= 2;

  /// True jika boleh melihat semua laporan user lain.
  /// Built-in admin+ ATAU custom role dengan bit permViewAll.
  bool get canViewAll => roleLevel >= 1 || (customRole?.canViewAll ?? false);

  /// True jika boleh menggunakan toggle mode global.
  /// Built-in admin+ ATAU custom role dengan bit permGlobalMode.
  bool get canGlobalMode => roleLevel >= 1 || (customRole?.canGlobalMode ?? false);

  /// True jika boleh menghapus laporan.
  /// Built-in admin+ ATAU custom role dengan bit permDeleteReport.
  bool get canDeleteReport => roleLevel >= 1 || (customRole?.canDeleteReport ?? false);

  /// True jika boleh mengelola user.
  /// Built-in developer+ ATAU custom role dengan bit permManageUsers.
  bool get canManageUsers => roleLevel >= 2 || (customRole?.canManageUsers ?? false);

  /// True jika boleh export PDF/DOCX.
  /// Built-in admin+ ATAU custom role dengan bit permExport.
  /// Semua user bisa export laporan SENDIRI; gate ini untuk fitur export data lain.
  bool get canExport => roleLevel >= 1 || (customRole?.canExport ?? false);

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
      // Simpan custom role sebagai nested object agar bisa di-restore
      if (customRole != null) 'customRole': customRole!.toJson(),
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    CustomRole? cr;
    if (json['customRole'] != null) {
      try {
        cr = CustomRole.fromMap(json['customRole'] as Map<String, dynamic>);
      } catch (_) {}
    }
    return UserSession(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nama: json['nama'] as String,
      puskesmas: json['puskesmas'] as String,
      bulan: json['bulan'] as String,
      tahun: json['tahun'] as String,
      role: json['role'] as String? ?? 'user',
      customRole: cr,
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
    CustomRole? customRole,
    bool clearCustomRole = false,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      nama: nama ?? this.nama,
      puskesmas: puskesmas ?? this.puskesmas,
      bulan: bulan ?? this.bulan,
      tahun: tahun ?? this.tahun,
      role: role ?? this.role,
      customRole: clearCustomRole ? null : (customRole ?? this.customRole),
    );
  }
}
