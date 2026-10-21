import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/update_dialog.dart';

/// Informasi pembaruan aplikasi dari server Supabase.
class AppUpdateInfo {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;
  final DateTime? releasedAt;

  const AppUpdateInfo({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isMandatory = false,
    this.releasedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      versionCode: json['version_code'] as int? ?? 1,
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? 'Pembaruan sistem dan peningkatan stabilitas.',
      isMandatory: json['is_mandatory'] as bool? ?? false,
      releasedAt: json['released_at'] != null ? DateTime.tryParse(json['released_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'version_code': versionCode,
    'download_url': downloadUrl,
    'release_notes': releaseNotes,
    'is_mandatory': isMandatory,
    'released_at': (releasedAt ?? DateTime.now()).toIso8601String(),
  };
}

/// Service untuk menangani In-App Auto Update (OTA Update).
class UpdateService {
  /// Versi aplikasi saat ini (sesuai pubspec.yaml: 2.7.5+9)
  static const String currentVersion = '2.7.5';
  static const int currentVersionCode = 9;

  static SupabaseClient get _client => Supabase.instance.client;

  /// Bandingkan apakah serverVersion lebih baru dari localVersion
  static bool isVersionNewer(String serverVersion, String localVersion) {
    try {
      final sParts = serverVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = localVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (sParts.length < 3) {
        sParts.add(0);
      }
      while (lParts.length < 3) {
        lParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (sParts[i] > lParts[i]) return true;
        if (sParts[i] < lParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah ada update baru di Supabase.
  /// Mengembalikan [AppUpdateInfo] jika ada versi baru, atau `null` jika sudah yang terbaru.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final res = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'app_update')
          .maybeSingle();

      if (res == null || res['value'] == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(res['value'] as Map);
      final updateInfo = AppUpdateInfo.fromJson(data);

      if (updateInfo.downloadUrl.trim().isEmpty) {
        return null;
      }

      // Cek apakah versi lebih baru berdasarkan versionCode atau format string
      final isNewerByCode = updateInfo.versionCode > currentVersionCode;
      final isNewerByString = isVersionNewer(updateInfo.version, currentVersion);

      if (isNewerByCode || isNewerByString) {
        debugPrint('[UpdateService] Update ditemukan: v${updateInfo.version} (current: v$currentVersion)');
        return updateInfo;
      }

      return null;
    } catch (e) {
      debugPrint('[UpdateService] Gagal memeriksa update: $e');
      return null;
    }
  }

  /// Ambil data konfigurasi update terakhir (untuk tampilan Admin)
  static Future<AppUpdateInfo?> getLatestPublishedConfig() async {
    try {
      final res = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'app_update')
          .maybeSingle();

      if (res != null && res['value'] != null) {
        final data = Map<String, dynamic>.from(res['value'] as Map);
        return AppUpdateInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[UpdateService] getLatestPublishedConfig error: $e');
      return null;
    }
  }

  /// Download file APK dengan stream progress callback
  static Future<File> downloadApk(
    String downloadUrl,
    String targetVersion, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(downloadUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('Server mengembalikan HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/laporan_kunjungan_v$targetVersion.apk');

      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null) {
          final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : -1.0;
          onProgress(progress, receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      return apkFile;
    } finally {
      client.close();
    }
  }

  /// Jalankan package installer Android untuk memasang file APK
  static Future<bool> installApk(File apkFile) async {
    try {
      if (!await apkFile.exists()) return false;

      final result = await OpenFile.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[UpdateService] OpenFile result: ${result.type} - ${result.message}');
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[UpdateService] Gagal membuka installer APK: $e');
      return false;
    }
  }

  /// Cek pembaruan dan tampilkan dialog jika tersedia
  /// [silent]: jika true, tidak akan menampilkan dialog apapun jika aplikasi sudah yang terbaru
  static Future<void> checkAndShowUpdate(BuildContext context, {bool silent = false}) async {
    final updateInfo = await checkForUpdate();

    if (!context.mounted) return;

    if (updateInfo != null) {
      // Tampilkan popup update
      showDialog(
        context: context,
        barrierDismissible: !updateInfo.isMandatory,
        builder: (_) => UpdateDialog(updateInfo: updateInfo),
      );
    } else if (!silent) {
      // Dipicu manual oleh user dan aplikasi sudah paling baru
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Aplikasi sudah menggunakan versi terbaru (v$currentVersion) ✨'),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Admin: Publikasikan versi update baru ke server Supabase
  static Future<String?> publishUpdate({
    required String version,
    required int versionCode,
    required String downloadUrl,
    required String releaseNotes,
    required bool isMandatory,
  }) async {
    try {
      final info = AppUpdateInfo(
        version: version.trim(),
        versionCode: versionCode,
        downloadUrl: downloadUrl.trim(),
        releaseNotes: releaseNotes.trim(),
        isMandatory: isMandatory,
        releasedAt: DateTime.now(),
      );

      await _client.from('app_config').upsert({
        'key': 'app_update',
        'value': info.toJson(),
      });

      return null; // Sukses
    } catch (e) {
      debugPrint('[UpdateService] publishUpdate error: $e');
      return e.toString();
    }
  }
}
