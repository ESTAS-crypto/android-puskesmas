import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';

class StorageService {
  static const String _sessionKey = 'user_session';
  static const String _reportsKey = 'reports';
  static const String _draftKey = 'draft_report';

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
  }

  static Future<void> updateReport(Report report) async {
    final reports = await getReports();
    final index = reports.indexWhere((r) => r.id == report.id);
    if (index != -1) {
      reports[index] = report;
      await _saveReports(reports);
    }
  }

  static Future<void> deleteReport(String id) async {
    final reports = await getReports();
    reports.removeWhere((r) => r.id == id);
    await _saveReports(reports);
  }

  static Future<void> _saveReports(List<Report> reports) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = reports.map((r) => r.toJson()).toList();
    await prefs.setString(_reportsKey, jsonEncode(jsonList));
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
