import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Data pemeriksaan satu warga dalam satu laporan.
class ResidentExam {
  final String id;
  final String tanggal;
  final String nama;
  final String nik;
  final String usia;
  final String alamat;
  final String kategoriKeluarga;
  final String bb;
  final String tb;
  final String lingkarPinggang;
  final String tensi;
  final String lila;
  final String lika;
  final String gulaDarah;
  final List<String> keluhan;
  final List<String> tindakLanjut;
  final String? fotoPath;
  final Map<String, String> customFields;

  ResidentExam({
    String? id,
    required this.tanggal,
    required this.nama,
    this.nik = '',
    required this.usia,
    required this.alamat,
    this.kategoriKeluarga = '',
    this.bb = '',
    this.tb = '',
    this.lingkarPinggang = '',
    this.tensi = '',
    this.lila = '',
    this.lika = '',
    this.gulaDarah = '',
    required this.keluhan,
    required this.tindakLanjut,
    this.fotoPath,
    this.customFields = const {},
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'tanggal': tanggal,
        'nama': nama,
        'nik': nik,
        'usia': usia,
        'alamat': alamat,
        'kategoriKeluarga': kategoriKeluarga,
        'bb': bb,
        'tb': tb,
        'lingkarPinggang': lingkarPinggang,
        'tensi': tensi,
        'lila': lila,
        'lika': lika,
        'gulaDarah': gulaDarah,
        'keluhan': keluhan,
        'tindakLanjut': tindakLanjut,
        'fotoPath': fotoPath,
        'customFields': customFields,
      };

  factory ResidentExam.fromJson(Map<String, dynamic> json) => ResidentExam(
        id: json['id'] as String? ?? const Uuid().v4(),
        tanggal: json['tanggal'] as String? ?? '',
        nama: json['nama'] as String? ?? '',
        nik: json['nik'] as String? ?? '',
        usia: json['usia'] as String? ?? '',
        alamat: json['alamat'] as String? ?? '',
        kategoriKeluarga: json['kategoriKeluarga'] as String? ?? '',
        bb: json['bb'] as String? ?? '',
        tb: json['tb'] as String? ?? '',
        lingkarPinggang: json['lingkarPinggang'] as String? ?? '',
        tensi: json['tensi'] as String? ?? '',
        lila: json['lila'] as String? ?? '',
        lika: json['lika'] as String? ?? '',
        gulaDarah: json['gulaDarah'] as String? ?? '',
        keluhan: List<String>.from(json['keluhan'] as List? ?? []),
        tindakLanjut: List<String>.from(json['tindakLanjut'] as List? ?? []),
        fotoPath: json['fotoPath'] as String?,
        customFields: json['customFields'] != null
            ? Map<String, String>.from(json['customFields'] as Map)
            : {},
      );

  String toJsonString() => jsonEncode(toJson());
}
