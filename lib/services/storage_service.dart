import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';
import 'supabase_service.dart';

class StorageService {
  static const String _sessionKey = 'user_session';
  static const String _reportsKey = 'reports';
  static const String _draftKey = 'draft_report';
  static const String _pendingSyncKey = 'pending_sync_ids'; // ponytail: track unsynced reports

  // User Session
  static Future<void> saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, session.toJsonString());
  }

  static Future<UserSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStr = prefs.getString(_sessionKey);
    if (sessionStr == null) return null;
    return UserSession.fromJsonString(sessionStr);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  // Reports
  static Future<List<Report>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final reportsStr = prefs.getString(_reportsKey);
    if (reportsStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(reportsStr);
    return jsonList.map((e) => Report.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> saveReport(Report report) async {
    final reports = await getReports();
    reports.add(report);
    await _saveReports(reports);

    // ponytail: sync ke Supabase, track jika gagal
    await addPendingSync(report.id);
    try {
      await SupabaseService.syncReportToCloud(report);
      await removePendingSync(report.id);
    } catch (_) {
      debugPrint('[StorageService] Sync gagal untuk report ${report.id}, ditandai pending');
    }
  }

  /// Simpan report hanya ke lokal (tanpa sync ke cloud).
  /// Dipakai saat download data dari cloud agar tidak re-upload.
  static Future<void> saveReportLocalOnly(Report report) async {
    final reports = await getReports();
    reports.add(report);
    await _saveReports(reports);
  }

  static Future<void> updateReport(Report report) async {
    final reports = await getReports();
    final index = reports.indexWhere((r) => r.id == report.id);
    if (index != -1) {
      reports[index] = report;
      await _saveReports(reports);

      // ponytail: sync ke Supabase, track jika gagal
      await addPendingSync(report.id);
      try {
        await SupabaseService.syncReportToCloud(report);
        await removePendingSync(report.id);
      } catch (_) {
        debugPrint('[StorageService] Sync update gagal untuk report ${report.id}');
      }
    }
  }

  static Future<void> deleteReport(String id) async {
    final reports = await getReports();
    reports.removeWhere((r) => r.id == id);
    await _saveReports(reports);

    // Hapus dari Supabase
    SupabaseService.deleteReportFromCloud(id);
  }

  static Future<void> _saveReports(List<Report> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = reports.map((r) => r.toJson()).toList();
    await prefs.setString(_reportsKey, jsonEncode(jsonList));
  }

  // Sync manual: upload semua data lokal ke cloud
  static Future<void> syncAllToCloud() async {
    final reports = await getReports();
    await SupabaseService.syncAllToCloud(reports);
  }

  // ── PENDING SYNC TRACKING ──────────────────
  // ponytail: minimal — just a set of IDs in SharedPreferences

  static Future<Set<String>> getPendingSyncIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_pendingSyncKey);
    return list?.toSet() ?? {};
  }

  static Future<int> getPendingSyncCount() async {
    return (await getPendingSyncIds()).length;
  }

  static Future<void> addPendingSync(String reportId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_pendingSyncKey) ?? []).toSet();
    ids.add(reportId);
    await prefs.setStringList(_pendingSyncKey, ids.toList());
  }

  static Future<void> removePendingSync(String reportId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_pendingSyncKey) ?? []).toSet();
    ids.remove(reportId);
    await prefs.setStringList(_pendingSyncKey, ids.toList());
  }

  /// Sync hanya laporan yang belum ter-sync. Return jumlah yang berhasil.
  static Future<int> syncPendingReports() async {
    final pendingIds = await getPendingSyncIds();
    if (pendingIds.isEmpty) return 0;

    final reports = await getReports();
    int synced = 0;
    for (final report in reports) {
      if (pendingIds.contains(report.id)) {
        try {
          await SupabaseService.syncReportToCloud(report);
          await removePendingSync(report.id);
          synced++;
        } catch (_) {
          debugPrint('[StorageService] Pending sync gagal untuk ${report.id}');
        }
      }
    }
    debugPrint('[StorageService] syncPendingReports: $synced/${pendingIds.length} berhasil');
    return synced;
  }

  // ── AUTO-CLEANUP LOKAL ──────────────────────
  /// Hapus laporan lokal (beserta foto di disk) jika usianya lebih dari
  /// batas hari yang sudah ditentukan admin via remote config.
  /// Mengembalikan jumlah laporan yang dihapus.
  static Future<int> cleanupOldLocalData() async {
    try {
      // Ambil batas hari dari cache lokal (berfungsi offline)
      int deleteDays = await SupabaseService.getCachedLocalDeleteDays();

      // Jika online, coba fetch config terbaru dari server terlebih dahulu
      if (SupabaseService.isLoggedIn) {
        try {
          deleteDays = await SupabaseService.fetchAndCacheLocalDeleteConfig();
        } catch (_) {}
      }

      if (deleteDays <= 0) return 0; // Fitur nonaktif

      final now = DateTime.now();
      final reports = await getReports();
      final List<Report> toKeep = [];
      int deletedCount = 0;

      for (final report in reports) {
        final age = now.difference(report.createdAt).inDays;
        if (age > deleteDays) {
          // Hapus foto lokal dari disk
          for (final exam in report.exams) {
            if (exam.fotoPath != null && !exam.fotoPath!.startsWith('http')) {
              try {
                final file = File(exam.fotoPath!);
                if (file.existsSync()) {
                  file.deleteSync();
                  debugPrint('[StorageService] Deleted local photo: ${exam.fotoPath}');
                }
              } catch (_) {}
            }
          }
          deletedCount++;
          debugPrint('[StorageService] Cleanup: deleted report #${report.no} (age: $age days > $deleteDays)');
        } else {
          toKeep.add(report);
        }
      }

      if (deletedCount > 0) {
        await _saveReports(toKeep);
        debugPrint('[StorageService] Cleanup selesai: $deletedCount laporan + foto dihapus');
      }
      return deletedCount;
    } catch (e) {
      debugPrint('[StorageService] cleanupOldLocalData error: $e');
      return 0;
    }
  }

  // Drafts
  static Future<void> saveDraft(Report report) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, report.toJsonString());
  }

  static Future<Report?> getDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftStr = prefs.getString(_draftKey);
    if (draftStr == null) return null;
    try {
      return Report.fromJsonString(draftStr);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  // Auto-complete Helpers
  static Future<List<ResidentExam>> getAllResidents() async {
    final reports = await getReports();
    final Map<String, ResidentExam> uniqueMap = {};
    for (final r in reports) {
      for (final exam in r.exams) {
        final key = exam.nama.trim().toLowerCase();
        // Keep the latest if there are duplicates
        uniqueMap[key] = exam;
      }
    }
    return uniqueMap.values.toList();
  }

  static Future<int> getNextReportNo() async {
    final reports = await getReports();
    if (reports.isEmpty) return 1;
    return reports.map((r) => r.no).reduce((a, b) => a > b ? a : b) + 1;
  }
}
