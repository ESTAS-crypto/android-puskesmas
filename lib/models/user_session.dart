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

  bool get isAdmin => role == 'admin';

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
