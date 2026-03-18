import 'dart:convert';
import 'package:uuid/uuid.dart';

class Report {
  final String id;
  final int no;
  final String tanggal;
  final String nama;
  final String usia;
  final String alamat;
  final String bb;
  final String tb;
  final String lingkarPinggang;
  final String tensi;
  final String lila;
  final String lika;
  final String gulaDarah;
  final String kategoriKeluarga;
  final List<String> keluhan;
  final List<String> tindakLanjut;
  final String? fotoPath;
  final DateTime createdAt;
  final Map<String, String> customFields;

  Report({
    String? id,
    required this.no,
    required this.tanggal,
    required this.nama,
    required this.usia,
    required this.alamat,
    required this.bb,
    required this.tb,
    required this.lingkarPinggang,
    required this.tensi,
    this.lila = '',
    this.lika = '',
    this.gulaDarah = '',
    this.kategoriKeluarga = '',
    required this.keluhan,
    required this.tindakLanjut,
    this.fotoPath,
    DateTime? createdAt,
    this.customFields = const {},
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'no': no,
      'tanggal': tanggal,
      'nama': nama,
      'usia': usia,
      'alamat': alamat,
      'bb': bb,
      'tb': tb,
      'lingkarPinggang': lingkarPinggang,
      'tensi': tensi,
      'lila': lila,
      'lika': lika,
      'gulaDarah': gulaDarah,
      'kategoriKeluarga': kategoriKeluarga,
      'keluhan': keluhan,
      'tindakLanjut': tindakLanjut,
      'fotoPath': fotoPath,
      'createdAt': createdAt.toIso8601String(),
      'customFields': customFields,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      no: json['no'] as int,
      tanggal: json['tanggal'] as String,
      nama: json['nama'] as String,
      usia: json['usia'] as String,
      alamat: json['alamat'] as String,
      bb: json['bb'] as String,
      tb: json['tb'] as String,
      lingkarPinggang: json['lingkarPinggang'] as String,
      tensi: json['tensi'] as String,
      lila: json['lila'] as String? ?? '',
      lika: json['lika'] as String? ?? '',
      gulaDarah: json['gulaDarah'] as String? ?? '',
      kategoriKeluarga: json['kategoriKeluarga'] as String? ?? '',
      keluhan: List<String>.from(json['keluhan'] as List),
      tindakLanjut: List<String>.from(json['tindakLanjut'] as List),
      fotoPath: json['fotoPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      customFields: json['customFields'] != null
          ? Map<String, String>.from(json['customFields'] as Map)
          : {},
    );
  }

  String toJsonString() => jsonEncode(toJson());
  
  static Report fromJsonString(String jsonStr) =>
      Report.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
