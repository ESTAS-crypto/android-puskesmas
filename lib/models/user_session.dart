import 'dart:convert';

class UserSession {
  final String nama;
  final String puskesmas;
  final String bulan;
  final String tahun;

  UserSession({
    required this.nama,
    required this.puskesmas,
    required this.bulan,
    required this.tahun,
  });

  Map<String, dynamic> toJson() {
    return {
      'nama': nama,
      'puskesmas': puskesmas,
      'bulan': bulan,
      'tahun': tahun,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      nama: json['nama'] as String,
      puskesmas: json['puskesmas'] as String,
      bulan: json['bulan'] as String,
      tahun: json['tahun'] as String,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static UserSession fromJsonString(String jsonStr) =>
      UserSession.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  String get bulanTahun => '$bulan $tahun';
}
