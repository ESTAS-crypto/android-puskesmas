import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/report.dart';
import '../models/user_session.dart';

class DocxService {
  static Future<String> generateDocx({
    required List<Report> reports,
    required UserSession session,
  }) async {
    try {
      // Debug logging removed for production
      final dir = await _getOutputDir();
      final fileName = 'Laporan_Kunjungan_Rumah_${session.bulan}_${session.tahun}_${DateTime.now().millisecondsSinceEpoch}.docx';
      final filePath = '${dir.path}/$fileName';

      // Image relationships and parts
      final imageRelationships = StringBuffer();
      final imageParts = <String, Uint8List>{};
      int imageIndex = 1;

      final bodyXml = StringBuffer();
      
      int rowNo = 1;
      int totalExams = reports.fold(0, (sum, r) => sum + r.exams.length);
      int currentExam = 0;

      for (final report in reports) {
        for (final exam in report.exams) {
          currentExam++;
          
          bodyXml.write('<w:p><w:pPr><w:spacing w:after="60" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr>');
          bodyXml.write('<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>');
          bodyXml.write('<w:t>LAPORAN KUNJUNGAN RUMAH</w:t></w:r></w:p>');

          bodyXml.write('<w:p><w:pPr><w:spacing w:after="60" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr>');
          bodyXml.write('<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>');
          bodyXml.write('<w:t>PUSKESMAS ${_esc(session.puskesmas.toUpperCase())}</w:t></w:r></w:p>');

          bodyXml.write('<w:p><w:pPr><w:spacing w:after="200" w:line="240" w:lineRule="auto"/><w:jc w:val="center"/></w:pPr>');
          bodyXml.write('<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>');
          bodyXml.write('<w:t>BULAN ${_esc(session.bulan.toUpperCase())} TAHUN ${_esc(session.tahun)}</w:t></w:r></w:p>');

          bodyXml.write('<w:p><w:pPr><w:spacing w:after="120" w:line="240" w:lineRule="auto"/></w:pPr>');
          bodyXml.write('<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>');
          bodyXml.write('<w:t xml:space="preserve">Kader yang melakukan kunjungan rumah: ${_esc(session.nama)}</w:t></w:r></w:p>');

          bodyXml.write('''
    <w:tbl>
      <w:tblPr>
        <w:tblStyle w:val="TableGrid"/>
        <w:tblW w:w="9026" w:type="dxa"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
        </w:tblBorders>
        <w:tblLayout w:type="fixed"/>
        <w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>
      </w:tblPr>
      <w:tblGrid>
        <w:gridCol w:w="500"/>
        <w:gridCol w:w="1200"/>
        <w:gridCol w:w="4826"/>
        <w:gridCol w:w="2500"/>
      </w:tblGrid>
          ''');

          bodyXml.write('<w:tr><w:trPr><w:trHeight w:val="400"/></w:trPr>');
          bodyXml.write(_headerCell('NO', 'center'));
          bodyXml.write(_headerCell('TANGGAL', 'center'));
          bodyXml.write(_headerCell('HASIL', 'center'));
          bodyXml.write(_headerCell('FOTO GEOTAG', 'center'));
          bodyXml.write('</w:tr>');

          final hasil = StringBuffer();
          
          hasil.write(_sectionHeader('Identitas Pasien:'));
          hasil.write(_labelValue('Nama:', exam.nama));
          hasil.write(_labelValue('Alamat:', exam.alamat));
          hasil.write(_labelValue('NIK:', exam.nik.isNotEmpty ? exam.nik : '-'));
          hasil.write(_labelValue('Usia:', exam.usia));
          hasil.write(_spacer());

          hasil.write(_sectionHeader('Kategori Keluarga:'));
          if (exam.kategoriKeluarga.isNotEmpty) {
            hasil.write(_bulletItem(exam.kategoriKeluarga));
          } else {
            hasil.write(_bulletItem('-'));
          }
          hasil.write(_spacer());

          hasil.write(_sectionHeader('Keluhan/Permasalahan:'));
          if (exam.keluhan.isNotEmpty) {
            for (final k in exam.keluhan) {
              hasil.write(_bulletItem(k));
            }
          } else {
            hasil.write(_bulletItem('-'));
          }
          hasil.write(_spacer());

          hasil.write(_sectionHeader('Hasil Pemeriksaan:'));
          if (exam.bb.isNotEmpty) hasil.write(_bulletItem('BB : ${exam.bb} kg'));
          if (exam.tb.isNotEmpty) hasil.write(_bulletItem('TB : ${exam.tb} cm'));
          if (exam.lingkarPinggang.isNotEmpty) hasil.write(_bulletItem('LP : ${exam.lingkarPinggang} cm'));
          if (exam.lila.isNotEmpty) hasil.write(_bulletItem('LILA : ${exam.lila} cm'));
          if (exam.lika.isNotEmpty) hasil.write(_bulletItem('LiKa : ${exam.lika} cm'));
          if (exam.tensi.isNotEmpty) hasil.write(_bulletItem('Tensi : ${exam.tensi}'));
          if (exam.gulaDarah.isNotEmpty) hasil.write(_bulletItem('Gula Darah : ${exam.gulaDarah} mg/dL'));
          for (final entry in exam.customFields.entries) {
            hasil.write(_bulletItem('${entry.key} : ${entry.value}'));
          }
          hasil.write(_spacer());

          hasil.write(_sectionHeader('Tindak Lanjut:'));
          if (exam.tindakLanjut.isNotEmpty) {
            for (int i = 0; i < exam.tindakLanjut.length; i++) {
              hasil.write(_normalText('${i + 1}. ${exam.tindakLanjut[i]}'));
            }
          } else {
            hasil.write(_normalText('-'));
          }

          String fotoCellContent;
          if (exam.fotoPath != null && File(exam.fotoPath!).existsSync()) {
            try {
              final imageBytes = File(exam.fotoPath!).readAsBytesSync();
              final imgId = 'rId${10 + imageIndex}';
              final imgFile = 'image$imageIndex.jpg';
              imageParts['word/media/$imgFile'] = Uint8List.fromList(imageBytes);
              imageRelationships.write(
                '<Relationship Id="$imgId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$imgFile"/>');
              fotoCellContent = _imageCellXml(imgId, imageIndex);
              imageIndex++;
            } catch (_) {
              fotoCellContent = _dataCell(_centeredText('-'));
            }
          } else {
            fotoCellContent = _dataCell(_centeredText('-'));
          }

          bodyXml.write('<w:tr>');
          bodyXml.write(_dataCell(_centeredText(rowNo.toString())));
          bodyXml.write(_dataCell(_centeredText(exam.tanggal)));
          bodyXml.write(_dataCell(hasil.toString()));
          bodyXml.write(fotoCellContent);
          bodyXml.write('</w:tr>');

          bodyXml.write('</w:tbl>');
          
          if (currentExam < totalExams) {
             bodyXml.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
          }


          rowNo++;
        }
      }

      final documentXml = _buildDocumentXml(bodyXml.toString());
      final relsXml = _buildDocumentRels(imageRelationships.toString());

      // Create the DOCX (ZIP) archive
      final archive = Archive();
      _addXml(archive, '[Content_Types].xml', _contentTypesXml());
      _addXml(archive, '_rels/.rels', _rootRelsXml());
      _addXml(archive, 'word/document.xml', documentXml);
      _addXml(archive, 'word/_rels/document.xml.rels', relsXml);
      _addXml(archive, 'word/styles.xml', _stylesXml());
      _addXml(archive, 'word/settings.xml', _settingsXml());
      _addXml(archive, 'word/fontTable.xml', _fontTableXml());

      // Add images
      for (final entry in imageParts.entries) {
        archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
      }

      // Encode and save
      final encodedZip = ZipEncoder().encode(archive);
      if (encodedZip != null) {
        await File(filePath).writeAsBytes(encodedZip);

      }

      return filePath;
    } catch (e) {

      rethrow;
    }
  }

  // ====== XML Helpers ======

  static String _esc(String t) => t.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static String _sectionHeader(String text) =>
      '<w:p><w:pPr><w:spacing w:after="40" w:line="240" w:lineRule="auto"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:u w:val="single"/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';

  static String _labelValue(String label, String value) =>
      '<w:p><w:pPr><w:spacing w:after="20" w:line="240" w:lineRule="auto"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(label)} </w:t></w:r>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(value)}</w:t></w:r></w:p>';

  static String _bulletItem(String text) =>
      '<w:p><w:pPr><w:spacing w:after="20" w:line="276" w:lineRule="auto"/>'
      '<w:ind w:left="360" w:hanging="180"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
      '<w:t xml:space="preserve">- ${_esc(text)}</w:t></w:r></w:p>';

  static String _normalText(String text) =>
      '<w:p><w:pPr><w:spacing w:after="20" w:line="240" w:lineRule="auto"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';

  static String _centeredText(String text) =>
      '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
      '<w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';

  static String _spacer() =>
      '<w:p><w:pPr><w:spacing w:after="0" w:line="120" w:lineRule="auto"/></w:pPr></w:p>';

  static String _headerCell(String text, String align) =>
      '<w:tc><w:tcPr>'
      '<w:shd w:val="clear" w:color="auto" w:fill="E0E0E0"/>'
      '<w:vAlign w:val="center"/>'
      '</w:tcPr>'
      '<w:p><w:pPr><w:jc w:val="$align"/><w:spacing w:after="0"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:b/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>'
      '<w:t>${_esc(text)}</w:t></w:r></w:p></w:tc>';

  static String _dataCell(String paragraphsXml) {
    return '''
      <w:tc><w:tcPr><w:vAlign w:val="top"/></w:tcPr>$paragraphsXml</w:tc>
    ''';
  }

  // Image cell — fits within 2500 dxa column (~1.74in)
  // Image size: 1.4in x 1.86in = 1280160 x 1700784 EMU
  static String _imageCellXml(String rId, int idx) {
    const int cx = 1280160; // ~1.4 in
    const int cy = 1700784; // ~1.86 in
    final int docPrId = idx + 100;
    return '<w:tc><w:tcPr><w:vAlign w:val="center"/></w:tcPr>'
        '<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0"/></w:pPr>'
        '<w:r><w:rPr><w:noProof/></w:rPr>'
        '<w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="$docPrId" name="Picture $idx"/>'
        '<wp:cNvGraphicFramePr>'
        '<a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>'
        '</wp:cNvGraphicFramePr>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr>'
        '<pic:cNvPr id="$idx" name="image$idx.jpg"/>'
        '<pic:cNvPicPr/>'
        '</pic:nvPicPr>'
        '<pic:blipFill>'
        '<a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>'
        '<a:stretch><a:fillRect/></a:stretch>'
        '</pic:blipFill>'
        '<pic:spPr>'
        '<a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '</pic:spPr>'
        '</pic:pic>'
        '</a:graphicData>'
        '</a:graphic>'
        '</wp:inline>'
        '</w:drawing>'
        '</w:r></w:p></w:tc>';
  }

  // ====== Document Structure ======

  static String _buildDocumentXml(String bodyContentXml) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
  xmlns:o="urn:schemas-microsoft-com:office:office"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:v="urn:schemas-microsoft-com:vml"
  xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:w10="urn:schemas-microsoft-com:office:word"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
  xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
  xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
  xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
  xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
  mc:Ignorable="w14 wp14">
  <w:body>
    $bodyContentXml
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
      <w:cols w:space="708"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>''';
  }


  static String _buildDocumentRels(String imageRels) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/>
  $imageRels
</Relationships>''';
  }

  static String _contentTypesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>
</Types>''';
  }

  static String _rootRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  }

  static String _settingsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:zoom w:percent="100"/>
  <w:defaultTabStop w:val="720"/>
  <w:characterSpacingControl w:val="doNotCompress"/>
  <w:compat>
    <w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>
  </w:compat>
</w:settings>''';
  }

  static String _fontTableXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:font w:name="Calibri">
    <w:panose1 w:val="020F0502020204030204"/>
    <w:charset w:val="00"/>
    <w:family w:val="swiss"/>
    <w:pitch w:val="variable"/>
  </w:font>
  <w:font w:name="Times New Roman">
    <w:panose1 w:val="02020603050405020304"/>
    <w:charset w:val="00"/>
    <w:family w:val="roman"/>
    <w:pitch w:val="variable"/>
  </w:font>
</w:fonts>''';
  }

  static String _stylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:asciiTheme="minorHAnsi" w:hAnsiTheme="minorHAnsi" w:eastAsiaTheme="minorHAnsi" w:cstheme="minorBidi"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        <w:lang w:val="id-ID" w:eastAsia="en-US" w:bidi="ar-SA"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="160" w:line="259" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:basedOn w:val="TableNormal"/>
    <w:tblPr>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      </w:tblBorders>
    </w:tblPr>
  </w:style>
  <w:style w:type="table" w:default="1" w:styleId="TableNormal">
    <w:name w:val="Normal Table"/>
    <w:tblPr>
      <w:tblInd w:w="0" w:type="dxa"/>
      <w:tblCellMar>
        <w:top w:w="0" w:type="dxa"/>
        <w:left w:w="108" w:type="dxa"/>
        <w:bottom w:w="0" w:type="dxa"/>
        <w:right w:w="108" w:type="dxa"/>
      </w:tblCellMar>
    </w:tblPr>
  </w:style>
</w:styles>''';
  }

  static void _addXml(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static Future<Directory> _getOutputDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    return await getApplicationDocumentsDirectory();
  }
}
