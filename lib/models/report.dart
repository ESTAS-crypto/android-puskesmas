import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'resident_exam.dart';

/// Satu "Laporan" adalah satu sesi kunjungan yang bisa memuat banyak warga.
/// Setiap warga (ResidentExam) punya tanggal kunjungannya sendiri.
class Report {
  final String id;
  final int no;
  final DateTime createdAt;
  final List<ResidentExam> exams;

  Report({
    String? id,
    required this.no,
    DateTime? createdAt,
    List<ResidentExam>? exams,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        exams = exams ?? [];

  int get totalPasien => exams.length;

  /// Tanggal ditampilkan dari exam pertama jika ada
  String get tanggalDisplay {
    if (exams.isEmpty) return '-';
    final dates = exams.map((e) => e.tanggal).where((t) => t.isNotEmpty).toSet();
    if (dates.length == 1) return dates.first;
    return dates.take(2).join(', ') + (dates.length > 2 ? ', ...' : '');
  }

  String get summaryNames {
    if (exams.isEmpty) return '(Kosong)';
    if (exams.length == 1) return exams.first.nama;
    if (exams.length <= 3) return exams.map((e) => e.nama).join(', ');
    return '${exams.take(2).map((e) => e.nama).join(', ')} & ${exams.length - 2} lainnya';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'no': no,
        'createdAt': createdAt.toIso8601String(),
        'exams': exams.map((e) => e.toJson()).toList(),
        '_v': 2,
      };

  factory Report.fromJson(Map<String, dynamic> json) {
    // === MIGRATION: old format (v1: 1 Report = 1 Person, tanggal on Report) ===
    if (json['_v'] == null || (json['_v'] as int) < 2) {
      final reportTanggal = json['tanggal'] as String? ?? '';
      final exam = ResidentExam(
        id: json['id'] as String? ?? const Uuid().v4(),
        tanggal: reportTanggal,
        nama: json['nama'] as String? ?? '',
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
      return Report(
        id: json['id'] as String,
        no: json['no'] as int,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        exams: [exam],
      );
    }

    // === New format (v2: 1 Report = N Persons, tanggal on each ResidentExam) ===
    return Report(
      id: json['id'] as String,
      no: json['no'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      exams: (json['exams'] as List? ?? [])
          .map((e) => ResidentExam.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJsonString() => jsonEncode(toJson());
  static Report fromJsonString(String s) =>
      Report.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
