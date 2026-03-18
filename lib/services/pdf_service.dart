import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/report.dart';
import '../models/user_session.dart';

class PdfService {
  static Future<String> generatePdf({
    required List<Report> reports,
    required UserSession session,
  }) async {
    final pdf = pw.Document();

    final headerStyle = pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
    );

    final tableHeaderStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );

    final normalStyle = const pw.TextStyle(
      fontSize: 10,
    );

    final boldStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );

    // Bold + underlined for section headers inside HASIL
    final sectionHeaderStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      decoration: pw.TextDecoration.underline,
    );

    final petugasStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );

    // Build table rows with embedded photos
    final tableRows = <pw.TableRow>[];

    // Header row
    tableRows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: ['NO', 'TANGGAL', 'HASIL', 'FOTO GEOTAG'].map((h) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Center(
            child: pw.Text(h, style: tableHeaderStyle, textAlign: pw.TextAlign.center),
          ),
        );
      }).toList(),
    ));

    // Data rows
    for (final report in reports) {
      final hasilWidgets = <pw.Widget>[];

      // ===== 1. IDENTITAS PASIEN =====
      hasilWidgets.add(pw.Text('Identitas Pasien', style: sectionHeaderStyle));
      hasilWidgets.add(pw.SizedBox(height: 4));

      hasilWidgets.add(_buildLabelValue('Nama', report.nama, boldStyle, normalStyle));
      hasilWidgets.add(_buildLabelValue('Usia', report.usia, boldStyle, normalStyle));
      hasilWidgets.add(_buildLabelValue('Alamat', report.alamat, boldStyle, normalStyle));

      // ===== 2. KATEGORI KELUARGA =====
      hasilWidgets.add(pw.SizedBox(height: 8));
      hasilWidgets.add(pw.Text('Kategori Keluarga', style: sectionHeaderStyle));
      hasilWidgets.add(pw.SizedBox(height: 4));
      if (report.kategoriKeluarga.isNotEmpty) {
        hasilWidgets.add(pw.Text(report.kategoriKeluarga, style: normalStyle));
      } else {
        hasilWidgets.add(pw.Text('-', style: normalStyle));
      }

      // ===== 3. KELUHAN / PERMASALAHAN =====
      hasilWidgets.add(pw.SizedBox(height: 8));
      hasilWidgets.add(pw.Text('Keluhan / Permasalahan', style: sectionHeaderStyle));
      hasilWidgets.add(pw.SizedBox(height: 4));
      if (report.keluhan.isNotEmpty) {
        for (final k in report.keluhan) {
          hasilWidgets.add(pw.Text('- $k', style: normalStyle));
        }
      } else {
        hasilWidgets.add(pw.Text('-', style: normalStyle));
      }

      // ===== 4. HASIL PEMERIKSAAN =====
      hasilWidgets.add(pw.SizedBox(height: 8));
      hasilWidgets.add(pw.Text('Hasil Pemeriksaan', style: sectionHeaderStyle));
      hasilWidgets.add(pw.SizedBox(height: 4));

      if (report.bb.isNotEmpty) {
        hasilWidgets.add(_buildLabelValue('BB', '${report.bb} kg', boldStyle, normalStyle));
      }
      if (report.tb.isNotEmpty) {
        hasilWidgets.add(_buildLabelValue('TB', '${report.tb} cm', boldStyle, normalStyle));
      }
      if (report.lingkarPinggang.isNotEmpty) {
        hasilWidgets.add(_buildLabelValue('LP', '${report.lingkarPinggang} cm', boldStyle, normalStyle));
      }
      if (report.lila.isNotEmpty) {
        hasilWidgets.add(_buildLabelValue('LILA', '${report.lila} cm', boldStyle, normalStyle));
      }
      if (report.lika.isNotEmpty) {
        hasilWidgets.add(_buildLabelValue('LiKa', '${report.lika} cm', boldStyle, normalStyle));
      }
      hasilWidgets.add(_buildLabelValue('Tensi', report.tensi, boldStyle, normalStyle));
      if (report.gulaDarah.isNotEmpty) {
        hasilWidgets.add(_buildLabelValue('Gula Darah', '${report.gulaDarah} mg/dL', boldStyle, normalStyle));
      }
      // Custom fields
      for (final entry in report.customFields.entries) {
        hasilWidgets.add(_buildLabelValue(entry.key, entry.value, boldStyle, normalStyle));
      }

      // ===== 5. TINDAK LANJUT =====
      hasilWidgets.add(pw.SizedBox(height: 8));
      hasilWidgets.add(pw.Text('Tindak Lanjut', style: sectionHeaderStyle));
      hasilWidgets.add(pw.SizedBox(height: 4));
      if (report.tindakLanjut.isNotEmpty) {
        for (int i = 0; i < report.tindakLanjut.length; i++) {
          hasilWidgets.add(pw.Text('${i + 1}. ${report.tindakLanjut[i]}', style: normalStyle));
        }
      } else {
        hasilWidgets.add(pw.Text('-', style: normalStyle));
      }

      // Build foto cell — embed photo directly if available
      pw.Widget fotoWidget;
      if (report.fotoPath != null && File(report.fotoPath!).existsSync()) {
        try {
          final imageBytes = File(report.fotoPath!).readAsBytesSync();
          final image = pw.MemoryImage(imageBytes);
          fotoWidget = pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Center(
              child: pw.Image(image, width: 162, height: 220, fit: pw.BoxFit.contain),
            ),
          );
        } catch (_) {
          fotoWidget = pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Center(child: pw.Text('-', style: normalStyle)),
          );
        }
      } else {
        fotoWidget = pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Center(child: pw.Text('-', style: normalStyle)),
        );
      }

      tableRows.add(pw.TableRow(
        children: [
          // NO column - centered
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Center(
              child: pw.Text(report.no.toString(), style: normalStyle),
            ),
          ),
          // TANGGAL column - centered
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Center(
              child: pw.Text(report.tanggal, style: normalStyle),
            ),
          ),
          // HASIL column - left-aligned with 5 sections
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: hasilWidgets,
            ),
          ),
          // FOTO GEOTAG column - centered photo
          fotoWidget,
        ],
      ));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Centered title
              pw.Center(
                child: pw.Text('LAPORAN KUNJUNGAN RUMAH', style: headerStyle),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'PUSKESMAS ${session.puskesmas.toUpperCase()}',
                  style: headerStyle,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'BULAN ${session.bulan.toUpperCase()} TAHUN ${session.tahun}',
                  style: headerStyle,
                ),
              ),
              pw.SizedBox(height: 12),
              // Nama Petugas - top left, above table, outside table
              pw.Text(
                'Nama Petugas : ${session.nama}',
                style: petugasStyle,
              ),
            ],
          );
        },
        build: (context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(width: 1),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),   // NO
                1: const pw.FixedColumnWidth(70),   // TANGGAL
                2: const pw.FlexColumnWidth(3),      // HASIL
                3: const pw.FixedColumnWidth(170),   // FOTO GEOTAG
              },
              children: tableRows,
            ),
          ];
        },
      ),
    );

    final dir = await _getOutputDir();
    final fileName = 'Laporan_Kunjungan_Rumah_${session.bulan}_${session.tahun}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Helper to build a "Label : Value" line with bold label
  static pw.Widget _buildLabelValue(
    String label,
    String value,
    pw.TextStyle boldStyle,
    pw.TextStyle normalStyle,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label : ', style: boldStyle),
            pw.TextSpan(text: value, style: normalStyle),
          ],
        ),
      ),
    );
  }

  static Future<Directory> _getOutputDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    return await getApplicationDocumentsDirectory();
  }
}
