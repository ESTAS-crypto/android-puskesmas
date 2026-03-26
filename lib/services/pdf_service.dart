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

    // Each exam = one separate page with its own header + table
    int rowNo = 1;
    for (final report in reports) {
      for (final exam in report.exams) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            build: (context) {
              final pageWidgets = <pw.Widget>[];

              // Header
              pageWidgets.add(pw.Center(child: pw.Text('LAPORAN KUNJUNGAN RUMAH', style: headerStyle)));
              pageWidgets.add(pw.SizedBox(height: 4));
              pageWidgets.add(pw.Center(child: pw.Text('PUSKESMAS ${session.puskesmas.toUpperCase()}', style: headerStyle)));
              pageWidgets.add(pw.SizedBox(height: 4));
              pageWidgets.add(pw.Center(child: pw.Text('BULAN ${session.bulan.toUpperCase()} TAHUN ${session.tahun}', style: headerStyle)));
              pageWidgets.add(pw.SizedBox(height: 16));

              // Kader info above table
              pageWidgets.add(pw.Text('Kader yang melakukan kunjungan rumah : ${session.nama}', style: petugasStyle));
              pageWidgets.add(pw.SizedBox(height: 8));

              // Build HASIL widgets
              final hasilWidgets = <pw.Widget>[];

              hasilWidgets.add(pw.Text('Identitas Pasien', style: sectionHeaderStyle));
              hasilWidgets.add(pw.SizedBox(height: 4));
              hasilWidgets.add(_buildLabelValue('Nama', exam.nama, boldStyle, normalStyle));
              hasilWidgets.add(_buildLabelValue('Alamat', exam.alamat, boldStyle, normalStyle));
              hasilWidgets.add(_buildLabelValue('NIK', exam.nik.isNotEmpty ? exam.nik : '-', boldStyle, normalStyle));
              hasilWidgets.add(_buildLabelValue('Usia', exam.usia, boldStyle, normalStyle));

              hasilWidgets.add(pw.SizedBox(height: 8));
              hasilWidgets.add(pw.Text('Kategori Keluarga', style: sectionHeaderStyle));
              hasilWidgets.add(pw.SizedBox(height: 4));
              hasilWidgets.add(pw.Text(exam.kategoriKeluarga.isNotEmpty ? exam.kategoriKeluarga : '-', style: normalStyle));

              hasilWidgets.add(pw.SizedBox(height: 8));
              hasilWidgets.add(pw.Text('Keluhan / Permasalahan', style: sectionHeaderStyle));
              hasilWidgets.add(pw.SizedBox(height: 4));
              if (exam.keluhan.isNotEmpty) {
                for (final k in exam.keluhan) {
                  hasilWidgets.add(pw.Text('- $k', style: normalStyle));
                }
              } else {
                hasilWidgets.add(pw.Text('-', style: normalStyle));
              }

              hasilWidgets.add(pw.SizedBox(height: 8));
              hasilWidgets.add(pw.Text('Hasil Pemeriksaan', style: sectionHeaderStyle));
              hasilWidgets.add(pw.SizedBox(height: 4));
              if (exam.bb.isNotEmpty) hasilWidgets.add(_buildLabelValue('BB', '${exam.bb} kg', boldStyle, normalStyle));
              if (exam.tb.isNotEmpty) hasilWidgets.add(_buildLabelValue('TB', '${exam.tb} cm', boldStyle, normalStyle));
              if (exam.lingkarPinggang.isNotEmpty) hasilWidgets.add(_buildLabelValue('LP', '${exam.lingkarPinggang} cm', boldStyle, normalStyle));
              if (exam.lila.isNotEmpty) hasilWidgets.add(_buildLabelValue('LILA', '${exam.lila} cm', boldStyle, normalStyle));
              if (exam.lika.isNotEmpty) hasilWidgets.add(_buildLabelValue('LiKa', '${exam.lika} cm', boldStyle, normalStyle));
              if (exam.tensi.isNotEmpty) hasilWidgets.add(_buildLabelValue('Tensi', exam.tensi, boldStyle, normalStyle));
              if (exam.gulaDarah.isNotEmpty) hasilWidgets.add(_buildLabelValue('Gula Darah', '${exam.gulaDarah} mg/dL', boldStyle, normalStyle));
              for (final entry in exam.customFields.entries) {
                hasilWidgets.add(_buildLabelValue(entry.key, entry.value, boldStyle, normalStyle));
              }

              hasilWidgets.add(pw.SizedBox(height: 8));
              hasilWidgets.add(pw.Text('Tindak Lanjut', style: sectionHeaderStyle));
              hasilWidgets.add(pw.SizedBox(height: 4));
              if (exam.tindakLanjut.isNotEmpty) {
                for (int i = 0; i < exam.tindakLanjut.length; i++) {
                  hasilWidgets.add(pw.Text('${i + 1}. ${exam.tindakLanjut[i]}', style: normalStyle));
                }
              } else {
                hasilWidgets.add(pw.Text('-', style: normalStyle));
              }

              // Build foto cell
              pw.Widget fotoWidget;
              if (exam.fotoPath != null && File(exam.fotoPath!).existsSync()) {
                try {
                  final imageBytes = File(exam.fotoPath!).readAsBytesSync();
                  final image = pw.MemoryImage(imageBytes);
                  fotoWidget = pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Center(child: pw.Image(image, width: 162, height: 220, fit: pw.BoxFit.contain)),
                  );
                } catch (_) {
                  fotoWidget = pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('-', style: normalStyle)));
                }
              } else {
                fotoWidget = pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text('-', style: normalStyle)));
              }

              // Build the table with header row + single data row
              final table = pw.Table(
                border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(70),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FixedColumnWidth(170),
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('NO', style: tableHeaderStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('TANGGAL', style: tableHeaderStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('HASIL', style: tableHeaderStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text('FOTO GEOTAG', style: tableHeaderStyle))),
                    ],
                  ),
                  // Data row
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(rowNo.toString(), style: normalStyle))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Center(child: pw.Text(exam.tanggal, style: normalStyle))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: hasilWidgets,
                        ),
                      ),
                      fotoWidget,
                    ],
                  ),
                ],
              );

              pageWidgets.add(table);
              return pageWidgets;
            },
          ),
        );
        rowNo++;
      }
    }

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
