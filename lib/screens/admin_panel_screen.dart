import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';
import '../models/user_session.dart';
import '../services/docx_service.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../models/custom_role.dart';
import 'custom_roles_screen.dart';
import '../widgets/ui/ui.dart';
import 'admin/admin_user_tab.dart';
import 'admin/admin_laporan_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  final UserSession session;
  const AdminPanelScreen({super.key, required this.session});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _photos = [];
  bool _loadingUsers = false;
  bool _loadingReports = false;
  bool _loadingPhotos = false;
  int _totalStorageUsedBytes = 0;
  int _totalExamCount = 0;
  Map<String, CustomRole> _customRolesMap = {}; // roleId -> CustomRole

  // Auto-delete settings (terpisah foto & laporan) — SERVER/CLOUD
  int _photoDeleteValue = 0;   // 0 = nonaktif
  String _photoDeleteUnit = 'bulan'; // hari, minggu, bulan
  int _reportDeleteValue = 0;
  String _reportDeleteUnit = 'bulan';

  // Auto-delete LOKAL (HP petugas) — via remote config
  int _localDeleteValue = 0;
  String _localDeleteUnit = 'hari';

  // Supabase Health Status State
  bool _checkingSupabase = false;
  bool? _supabaseConnected;
  int _supabaseLatencyMs = 0;
  String _supabaseStatusMsg = 'Memeriksa koneksi Supabase...';
  bool _supabaseIsPaused = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadTabData(_tabController.index);
    });
    _loadTabData(0);
    _loadAutoDeleteSettings();
    _loadLocalDeleteConfig();
    _checkSupabaseConnection();
  }

  Future<void> _checkSupabaseConnection() async {
    if (!mounted) return;
    setState(() {
      _checkingSupabase = true;
      _supabaseStatusMsg = 'Memeriksa koneksi ke Supabase Cloud...';
    });
    final res = await SupabaseService.checkConnectionStatus();
    if (mounted) {
      setState(() {
        _checkingSupabase = false;
        _supabaseConnected = res['connected'] as bool? ?? false;
        _supabaseLatencyMs = res['latencyMs'] as int? ?? 0;
        _supabaseStatusMsg = res['message'] as String? ?? '';
        _supabaseIsPaused = res['isPaused'] as bool? ?? false;
      });
    }
  }

  // ═══════════════════════════════════════════════
  // OTA UPDATE MANAGEMENT
  // ═══════════════════════════════════════════════

  Future<void> _showPublishUpdateDialog() async {
    final currentConfig = await UpdateService.getLatestPublishedConfig();
    if (!mounted) return;

    final versionCtrl = TextEditingController(text: currentConfig?.version ?? UpdateService.currentVersion);
    final codeCtrl = TextEditingController(text: (currentConfig?.versionCode ?? UpdateService.currentVersionCode + 1).toString());
    final urlCtrl = TextEditingController(text: currentConfig?.downloadUrl ?? '');
    final notesCtrl = TextEditingController(
      text: currentConfig?.releaseNotes ?? '• Peningkatan performa aplikasi\n• Perbaikan bug dan kestabilan sistem',
    );
    bool isMandatory = currentConfig?.isMandatory ?? false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.accentTeal, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rilis Pembaruan Aplikasi (OTA)',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Otomatis terdeteksi & ter-update di HP semua user',
                              style: TextStyle(color: AppTheme.textHint, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: versionCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nomor Versi',
                            hintText: 'misal 2.8.0',
                            filled: true,
                            fillColor: AppTheme.secondaryDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: codeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Code',
                            hintText: '10',
                            filled: true,
                            fillColor: AppTheme.secondaryDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'URL Download File APK',
                      hintText: 'https://.../app-release.apk',
                      filled: true,
                      fillColor: AppTheme.secondaryDark,
                      prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.accentTeal),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: notesCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Catatan Rilis / Apa yang Baru',
                      hintText: '• Perbaikan...\n• Fitur baru...',
                      filled: true,
                      fillColor: AppTheme.secondaryDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    value: isMandatory,
                    onChanged: (val) => setModalState(() => isMandatory = val),
                    title: const Text('Wajib Update (Mandatory)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    subtitle: const Text('Pengguna tidak bisa melewati dialog update', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                    activeThumbColor: AppTheme.accentTeal,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final v = versionCtrl.text.trim();
                            final c = int.tryParse(codeCtrl.text.trim()) ?? 1;
                            final u = urlCtrl.text.trim();
                            final n = notesCtrl.text.trim();

                            if (v.isEmpty || u.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nomor versi dan URL APK tidak boleh kosong!')),
                              );
                              return;
                            }

                            setModalState(() => isSaving = true);
                            final err = await UpdateService.publishUpdate(
                              version: v,
                              versionCode: c,
                              downloadUrl: u,
                              releaseNotes: n,
                              isMandatory: isMandatory,
                            );

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);

                            if (!mounted) return;
                            if (err == null) {
                              _showSnack('✅ Berhasil merilis pembaruan v$v! Semua pengguna akan menerima notifikasi update.');
                            } else {
                              _showSnack('Gagal rilis update: $err', isError: true);
                            }
                          },
                    icon: isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_rounded),
                    label: Text(isSaving ? 'Menyimpan...' : 'Publikasikan Pembaruan Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // AUTO-DELETE SETTINGS
  // ═══════════════════════════════════════════════

  Future<void> _loadAutoDeleteSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _photoDeleteValue = prefs.getInt('ad_photo_val') ?? 0;
        _photoDeleteUnit = prefs.getString('ad_photo_unit') ?? 'bulan';
        _reportDeleteValue = prefs.getInt('ad_report_val') ?? 0;
        _reportDeleteUnit = prefs.getString('ad_report_unit') ?? 'bulan';
      });
    }
  }

  Future<void> _savePhotoDeleteSetting(int value, String unit) async {
    value = value.clamp(0, 365); // Batas wajar
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ad_photo_val', value);
    await prefs.setString('ad_photo_unit', unit);
    if (mounted) setState(() { _photoDeleteValue = value; _photoDeleteUnit = unit; });
  }

  Future<void> _saveReportDeleteSetting(int value, String unit) async {
    value = value.clamp(0, 365); // Batas wajar
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ad_report_val', value);
    await prefs.setString('ad_report_unit', unit);
    if (mounted) setState(() { _reportDeleteValue = value; _reportDeleteUnit = unit; });
  }

  Future<void> _loadLocalDeleteConfig() async {
    final prefs = await SharedPreferences.getInstance();
    int val = prefs.getInt('local_ad_val') ?? 0;
    String unit = prefs.getString('local_ad_unit') ?? 'hari';
    if (mounted) setState(() { _localDeleteValue = val; _localDeleteUnit = unit; });
    try {
      final result = await SupabaseService.fetchAndCacheLocalDeleteConfig();
      if (result > 0 && mounted) {
        final freshPrefs = await SharedPreferences.getInstance();
        setState(() {
          _localDeleteValue = freshPrefs.getInt('local_ad_val') ?? val;
          _localDeleteUnit = freshPrefs.getString('local_ad_unit') ?? unit;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLocalDeleteConfig(int value, String unit) async {
    setState(() { _localDeleteValue = value; _localDeleteUnit = unit; });
    final error = await SupabaseService.saveLocalDeleteConfig(value, unit);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      final prefs = await SharedPreferences.getInstance();
      int days = value;
      if (unit == 'minggu') days = value * 7;
      if (unit == 'bulan') days = value * 30;
      await prefs.setInt('local_ad_days', days);
      await prefs.setInt('local_ad_val', value);
      await prefs.setString('local_ad_unit', unit);
      _showSnack('Pengaturan auto-delete lokal tersimpan ke server');
    }
  }



  int _unitToDays(int value, String unit) {
    if (value <= 0) return 0;
    switch (unit) {
      case 'hari': return value;
      case 'minggu': return value * 7;
      case 'bulan': return value * 30;
      default: return value * 30;
    }
  }

  // ═══════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════

  Future<void> _loadTabData(int index) async {
    switch (index) {
      case 0: if (_users.isEmpty) _loadUsers(); break;
      case 1: if (_reports.isEmpty) _loadReports(); break;
      case 2: if (_photos.isEmpty) _loadPhotos(); break;
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    // Load users dan custom roles secara paralel
    final results = await Future.wait([
      SupabaseService.adminGetAllUsers(),
      SupabaseService.getCustomRoles(),
    ]);
    if (mounted) {
      final rolesData = results[1];
      final rolesMap = <String, CustomRole>{};
      for (final m in rolesData) {
        final role = CustomRole.fromMap(m);
        rolesMap[role.id] = role;
      }
      setState(() {
        _users = results[0];
        _customRolesMap = rolesMap;
        _loadingUsers = false;
      });
    }
  }

  Future<void> _loadReports() async {
    setState(() => _loadingReports = true);
    final reports = await SupabaseService.adminGetAllReports();
    final examCount = await SupabaseService.adminCountExams();
    if (mounted) setState(() { _reports = reports; _totalExamCount = examCount; _loadingReports = false; });
  }


  Future<void> _loadPhotos() async {
    setState(() => _loadingPhotos = true);
    final photos = await SupabaseService.adminListPhotos();
    int bytes = 0;
    for (final p in photos) {
      if (p['size'] != null && p['size'] is int) bytes += p['size'] as int;
    }
    if (mounted) setState(() { _photos = photos; _totalStorageUsedBytes = bytes; _loadingPhotos = false; });
  }

  Widget _buildSupabaseStatusCard() {
    final isConnected = _supabaseConnected == true;
    final isChecking = _checkingSupabase;
    final color = isChecking
        ? AppTheme.accent
        : (isConnected ? AppTheme.success : AppTheme.error);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  )
                : AppIcon(
                    isConnected ? AppGlyph.cloud : AppGlyph.warning,
                    color: color,
                    size: 18,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Status Cloud Supabase',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusPill(
                      label: isChecking
                          ? 'Checking'
                          : (isConnected ? 'Terkoneksi' : (_supabaseIsPaused ? 'Ter-pause' : 'Terputus')),
                      color: isConnected ? AppTheme.success : AppTheme.error,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _supabaseStatusMsg,
                  style: const TextStyle(
                    color: AppTheme.textFaint,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tes Koneksi Supabase',
            onPressed: isChecking ? null : _checkSupabaseConnection,
            icon: const AppIcon(
              AppGlyph.update,
              color: AppTheme.textMuted,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSegmentedTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final idx = _tabController.index;
          return Row(
            children: [
              _buildTabPill(0, 'User', idx == 0),
              _buildTabPill(1, 'Laporan', idx == 1),
              _buildTabPill(2, 'Foto', idx == 2),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabPill(int index, String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          _loadTabData(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: AppMotion.decelerate,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF0B2A40).withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.primaryDeep : AppTheme.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usedMB = _totalStorageUsedBytes / (1024 * 1024);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header (AdminUser.dc.html) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const AppIcon(AppGlyph.back, color: AppTheme.text, size: 22),
                      tooltip: 'Kembali',
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Panel admin',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _supabaseStatusMsg.isNotEmpty
                          ? '$_supabaseStatusMsg (Ping: ${_supabaseLatencyMs}ms)'
                          : 'Periksa Koneksi',
                      onPressed: _checkingSupabase ? null : _checkSupabaseConnection,
                      icon: _checkingSupabase
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                            )
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _supabaseConnected == true ? AppTheme.success : AppTheme.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                    if (widget.session.isDeveloper) ...[
                      IconButton(
                        tooltip: 'Rilis Pembaruan Aplikasi (OTA)',
                        onPressed: _showPublishUpdateDialog,
                        icon: const AppIcon(AppGlyph.cloud, color: AppTheme.primaryDeep, size: 22),
                      ),
                      IconButton(
                        tooltip: 'Kelola Role Custom',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CustomRolesScreen(session: widget.session)),
                        ).then((_) => _loadTabData(_tabController.index)),
                        icon: const AppIcon(AppGlyph.shield, color: AppTheme.primaryDeep, size: 22),
                      ),
                    ],
                  ],
                ),
              ),

              // ── 3 Stat Cards (AdminUser.dc.html line 33) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_users.length}',
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Pengguna',
                              style: TextStyle(
                                color: AppTheme.textFaint,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_reports.length}',
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Laporan',
                              style: TextStyle(
                                color: AppTheme.textFaint,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${usedMB.toStringAsFixed(0)} MB',
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Foto',
                              style: TextStyle(
                                color: AppTheme.textFaint,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_supabaseConnected == false || _supabaseIsPaused)
                _buildSupabaseStatusCard(),

              // ── Segmented Tabs: User | Laporan | Foto (AdminUser.dc.html line 32) ──
              _buildAdminSegmentedTabs(),

              // ── Tab Bar View ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    AdminUserTab(
                      session: widget.session,
                      users: _users,
                      customRolesMap: _customRolesMap,
                      loading: _loadingUsers,
                      onRefresh: _loadUsers,
                      onShowEditUser: _showEditUserDialog,
                      onSetRole: _showSetRoleDialog,
                      onResetPassword: _resetUserPassword,
                    ),
                    AdminLaporanTab(
                      session: widget.session,
                      reports: _reports,
                      loading: _loadingReports,
                      totalExamCount: _totalExamCount,
                      reportDeleteValue: _reportDeleteValue,
                      reportDeleteUnit: _reportDeleteUnit,
                      localDeleteValue: _localDeleteValue,
                      localDeleteUnit: _localDeleteUnit,
                      onRefresh: _loadReports,
                      onSaveReportDelete: _saveReportDeleteSetting,
                      onSaveLocalDelete: _saveLocalDeleteConfig,
                      onShowDetail: _showReportDetail,
                      onExport: _exportAdminReport,
                      onDeleteReport: _deleteReport,
                      onDeleteOldReports: _deleteOldReports,
                    ),
                    _buildPhotosTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    String label;
    switch (role) {
      case 'owner':
        color = const Color(0xFFFFD700);
        label = 'OWNER';
        break;
      case 'developer':
        color = const Color(0xFF00B4DB);
        label = 'DEV';
        break;
      case 'admin':
        color = AppTheme.primaryDeep;
        label = 'ADMIN';
        break;
      default:
        color = AppTheme.textMuted;
        label = 'USER';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner': return 'Owner';
      case 'developer': return 'Developer';
      case 'admin': return 'Admin';
      default: return 'User';
    }
  }

  Future<void> _showEditUserDialog(String userId, String nama, String email, String puskesmas) async {
    final namaCtrl = TextEditingController(text: nama);
    final emailCtrl = TextEditingController(text: email);
    final pkmCtrl = TextEditingController(text: puskesmas);
    final pwCtrl = TextEditingController();
    bool showPw = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Profil User', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogField(namaCtrl, 'Nama', Icons.person_rounded),
              const SizedBox(height: 12),
              _dialogField(emailCtrl, 'Email', Icons.email_rounded),
              const SizedBox(height: 12),
              _dialogField(pkmCtrl, 'Puskesmas', Icons.local_hospital_rounded),
              const SizedBox(height: 12),
              TextField(
                controller: pwCtrl, obscureText: !showPw,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Password Baru (opsional)', labelStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                  hintText: 'Kosongkan jika tidak diubah', hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.warning, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(showPw ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppTheme.textHint, size: 18),
                    onPressed: () => setDialogState(() => showPw = !showPw),
                  ),
                  filled: true, fillColor: AppTheme.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.warning)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Simpan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final error = await SupabaseService.adminUpdateProfile(userId,
        nama: namaCtrl.text.trim(), email: emailCtrl.text.trim(), puskesmas: pkmCtrl.text.trim());
    if (!mounted) return;
    if (error != null) { _showSnack(error, isError: true); return; }

    if (pwCtrl.text.trim().isNotEmpty) {
      final pwError = await SupabaseService.adminChangePassword(userId, pwCtrl.text.trim());
      if (!mounted) return;
      if (pwError != null) { _showSnack('Profil tersimpan, tapi password gagal: $pwError', isError: true); _loadUsers(); return; }
    }
    _showSnack('Profil berhasil diperbarui'); _loadUsers();
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.accentTeal, size: 18),
        filled: true, fillColor: AppTheme.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentTeal)),
      ),
    );
  }

  /// Dialog untuk memilih role baru (khusus developer/owner).
  /// Menampilkan role bawaan DAN custom role dari database.
  Future<void> _showSetRoleDialog(String targetUserId, String nama, String currentRole) async {
    final actorLevel = widget.session.roleLevel;

    // Built-in roles yang boleh diberikan (di bawah level aktor)
    final allRoles = <String, String>{
      'user': 'User',
      'admin': 'Admin',
      'developer': 'Developer',
      'owner': 'Owner',
    };
    final availableRoles = allRoles.entries
        .where((e) {
          final lvl = const {'user': 0, 'admin': 1, 'developer': 2, 'owner': 3}[e.key] ?? 0;
          return lvl < actorLevel && e.key != currentRole;
        })
        .toList();

    // Load custom roles dari database
    final customRoleMaps = await SupabaseService.getCustomRoles();
    if (!mounted) return;
    final customRoles = customRoleMaps.map((m) => CustomRole.fromMap(m)).toList();

    if (availableRoles.isEmpty && customRoles.isEmpty) {
      _showSnack('Tidak ada role yang tersedia untuk diberikan.', isError: true);
      return;
    }

    // Selection state: 'builtin:<roleKey>' atau 'custom:<roleId>'
    String? selectedValue = availableRoles.isNotEmpty ? 'builtin:${availableRoles.first.key}' : null;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.manage_accounts_rounded, color: Color(0xFFE040FB), size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('Ubah Role: $nama', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Role saat ini: ${_roleLabel(currentRole)}',
                style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // ── Built-in Roles ──
              if (availableRoles.isNotEmpty) ...[
                const Text('Role Bawaan:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ...availableRoles.map((entry) {
                  final lvl = const {'user': 0, 'admin': 1, 'developer': 2, 'owner': 3}[entry.key] ?? 0;
                  final roleColor = lvl >= 3 ? const Color(0xFFFFD700)
                      : lvl >= 2 ? const Color(0xFF00E5FF)
                      : lvl >= 1 ? const Color(0xFFE040FB)
                      : AppTheme.textHint;
                  final val = 'builtin:${entry.key}';
                  return RadioListTile<String>(
                    value: val,
                    groupValue: selectedValue,
                    onChanged: (v) => setDialogState(() => selectedValue = v),
                    activeColor: roleColor,
                    contentPadding: EdgeInsets.zero,
                    title: Row(children: [
                      _buildRoleBadge(entry.key),
                      const SizedBox(width: 8),
                      Text(entry.value, style: TextStyle(color: roleColor, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ],

              // ── Custom Roles ──
              if (customRoles.isNotEmpty) ...[
                const Divider(color: AppTheme.divider, height: 24),
                const Text('Custom Role:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ...customRoles.map((cr) {
                  final color = Color(cr.colorValue);
                  final icon = getCustomRoleIconData(cr.iconName);
                  final val = 'custom:${cr.id}';
                  return RadioListTile<String>(
                    value: val,
                    groupValue: selectedValue,
                    onChanged: (v) => setDialogState(() => selectedValue = v),
                    activeColor: color,
                    contentPadding: EdgeInsets.zero,
                    title: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, color: color, size: 12),
                          const SizedBox(width: 4),
                          Text(cr.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(cr.name, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: selectedValue != null ? () => Navigator.pop(ctx, true) : null,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Simpan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE040FB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || selectedValue == null) return;

    String? error;
    if (selectedValue!.startsWith('builtin:')) {
      final newRole = selectedValue!.replaceFirst('builtin:', '');
      // Set built-in role & clear custom role
      error = await SupabaseService.adminUpdateUserRole(
        widget.session.userId,
        targetUserId,
        newRole,
      );
      if (error == null) {
        // Clear any previously assigned custom role
        await SupabaseService.assignCustomRoleToUser(targetUserId, null);
      }
      if (!mounted) return;
      if (error != null) {
        _showSnack(error, isError: true);
      } else {
        _showSnack('Role "$nama" berhasil diubah ke ${_roleLabel(newRole)}');
        _loadUsers();
      }
    } else if (selectedValue!.startsWith('custom:')) {
      final customRoleId = selectedValue!.replaceFirst('custom:', '');
      final cr = customRoles.firstWhere((r) => r.id == customRoleId);
      error = await SupabaseService.assignCustomRoleToUser(targetUserId, customRoleId);
      if (!mounted) return;
      if (error != null) {
        _showSnack(error, isError: true);
      } else {
        _showSnack('Custom role "${cr.name}" berhasil diberikan ke "$nama"');
        _loadUsers();
      }
    }
  }

  Future<void> _resetUserPassword(String email, String nama) async {
    if (email.isEmpty) { _showSnack('User tidak punya email', isError: true); return; }
    final confirm = await _confirmDialog('Reset Password', 'Kirim email reset password ke "$nama" ($email)?');
    if (confirm != true) return;
    final error = await SupabaseService.resetPassword(email);
    if (!mounted) return;
    if (error != null) { _showSnack(error, isError: true); } else { _showSnack('Email reset password terkirim ke $email'); }
  }

  // ═══════════════════════════════════════════════
  // TAB 2: KELOLA LAPORAN + AUTO-DELETE
  // ═══════════════════════════════════════════════


  /// Export satu laporan dari admin panel ke PDF atau DOCX.
  Future<void> _exportAdminReport(
    String reportId, int no, String ownerNama, String ownerPkm, String format,
  ) async {
    try {
      // 1. Ambil data pasien dari Supabase
      final examMaps = await SupabaseService.adminGetReportExams(reportId);

      // 2. Konversi ke ResidentExam objects
      final exams = examMaps.map((m) {
        final keluhan = m['keluhan'];
        final tindakLanjut = m['tindak_lanjut'];
        return ResidentExam(
          id: m['id'] as String? ?? '',
          tanggal: m['tanggal'] as String? ?? '',
          nama: m['nama'] as String? ?? '',
          nik: m['nik'] as String? ?? '',
          usia: m['usia'] as String? ?? '',
          alamat: m['alamat'] as String? ?? '',
          bb: m['bb'] as String? ?? '',
          tb: m['tb'] as String? ?? '',
          tensi: m['tensi'] as String? ?? '',
          gulaDarah: m['gula_darah'] as String? ?? '',
          lingkarPinggang: m['lingkar_pinggang'] as String? ?? '',
          lila: m['lila'] as String? ?? '',
          lika: m['lika'] as String? ?? '',
          keluhan: keluhan is List ? List<String>.from(keluhan) : [],
          tindakLanjut: tindakLanjut is List ? List<String>.from(tindakLanjut) : [],
          fotoPath: m['foto_path'] as String?, // ponytail: was missing — foto never exported
        );
      }).toList();

      // 3. Buat Report object
      final report = Report(no: no, exams: exams);

      // 4. Buat session tiruan dari data pemilik laporan
      final now = DateTime.now();
      final bulanNames = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
      final fakeSession = UserSession(
        nama: ownerNama,
        puskesmas: ownerPkm.isNotEmpty ? ownerPkm : widget.session.puskesmas,
        bulan: bulanNames[now.month],
        tahun: '${now.year}',
      );

      // 5. Generate file
      final String path;
      if (format == 'pdf') {
        path = await PdfService.generatePdf(reports: [report], session: fakeSession);
      } else {
        path = await DocxService.generateDocx(reports: [report], session: fakeSession);
      }

      if (!mounted) return;
      _showAdminExportSuccess(path, format.toUpperCase());
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal export: $e', isError: true);
    }
  }

  void _showAdminExportSuccess(String path, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 14),
            Text('File $type Berhasil!',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(path.split(RegExp(r'[\\/]')).last,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); OpenFile.open(path); },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.accentTeal),
                  label: const Text('Buka', style: TextStyle(color: AppTheme.accentTeal, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accentTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); Share.shareXFiles([XFile(path)]); },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Bagikan', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _showReportDetail(String reportId, int no) async {
    showModalBottomSheet(
      context: context, backgroundColor: AppTheme.cardDark, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportDetailSheet(reportId: reportId, no: no, photos: _photos),
    );
  }

  Future<void> _deleteReport(String reportId, int no) async {
    final confirm = await _confirmDialog('Hapus Laporan', 'Hapus Laporan #$no beserta semua data pasien?\n\nTidak bisa dibatalkan.');
    if (confirm != true) return;
    final error = await SupabaseService.adminDeleteReport(reportId);
    if (!mounted) return;
    if (error != null) { _showSnack(error, isError: true); } else { _showSnack('Laporan #$no dihapus'); _loadReports(); }
  }

  Future<void> _deleteOldReports(List<Map<String, dynamic>> oldReports) async {
    final confirm = await _confirmDialog(
      'Hapus Laporan Lama',
      'Hapus ${oldReports.length} laporan yang lebih dari $_reportDeleteValue $_reportDeleteUnit?\n\nSemua data pasien dalam laporan ini ikut terhapus.\n\nTidak bisa dibatalkan.',
    );
    if (confirm != true) return;
    int deleted = 0;
    for (final r in oldReports) {
      final id = r['id'] as String? ?? '';
      if (id.isEmpty) continue;
      final err = await SupabaseService.adminDeleteReport(id);
      if (err == null) deleted++;
    }
    if (!mounted) return;
    _showSnack('$deleted laporan lama dihapus');
    _loadReports();
  }

  // ═══════════════════════════════════════════════
  // TAB 3: KELOLA FOTO + AUTO-DELETE
  // ═══════════════════════════════════════════════

  Widget _buildPhotosTab() {
    if (_loadingPhotos) return _buildLoading();

    final deleteDays = _unitToDays(_photoDeleteValue, _photoDeleteUnit);
    final oldPhotos = _photos.where((p) {
      if (deleteDays <= 0) return false;
      final ca = p['created_at'];
      if (ca == null || ca.toString().isEmpty) return false;
      try { return DateTime.now().difference(DateTime.parse(ca.toString())).inDays > deleteDays; } catch (_) { return false; }
    }).toList();

    return RefreshIndicator(
      color: const Color(0xFFE040FB),
      onRefresh: _loadPhotos,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildStorageCard(),
          ),
          SliverToBoxAdapter(
            child: _buildAutoDeleteCard(
              icon: Icons.photo_library_rounded,
              title: 'Auto-Delete Foto',
              value: _photoDeleteValue,
              unit: _photoDeleteUnit,
              oldCount: oldPhotos.length,
              onSave: _savePhotoDeleteSetting,
              onDeleteOld: () => _deleteOldPhotos(oldPhotos),
            ),
          ),
          if (_photos.isEmpty)
            const SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.photo_library_rounded, size: 48, color: AppTheme.textHint), SizedBox(height: 12),
              Text('Tidak ada foto di storage', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ])))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPhotoCard(_photos[index], deleteDays),
                  childCount: _photos.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo, int deleteDays) {
    final name = photo['name'] as String? ?? '';
    final url = photo['url'] as String? ?? '';
    final size = photo['size'];
    final createdAt = photo['created_at'];
    String sizeStr = '-';
    if (size != null && size is int && size > 0) {
      sizeStr = size > 1024 * 1024 ? '${(size / 1024 / 1024).toStringAsFixed(1)} MB' : '${(size / 1024).toStringAsFixed(0)} KB';
    }
    String dateStr = '-';
    bool isOld = false;
    if (createdAt != null && createdAt.toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt.toString());
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
        if (deleteDays > 0) isOld = DateTime.now().difference(dt).inDays > deleteDays;
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOld ? AppTheme.error.withValues(alpha: 0.4) : AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: Stack(children: [
          GestureDetector(
            onTap: url.isNotEmpty ? () => _showPhotoPreview(context, url, name) : null,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover, width: double.infinity, cacheWidth: 300,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.textHint, size: 40)))
                  : const Center(child: Icon(Icons.image_rounded, color: AppTheme.textHint, size: 40)),
            ),
          ),
          if (url.isNotEmpty) Positioned(bottom: 6, right: 6, child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
          )),
          if (isOld) Positioned(top: 6, right: 6, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(6)),
            child: const Text('LAMA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
          )),
        ])),
        Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.length > 18 ? '${name.substring(0, 15)}...' : name,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 10, color: AppTheme.textHint), const SizedBox(width: 4),
            Text(dateStr, style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
            const Spacer(),
            Text(sizeStr, style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
          ]),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 28, child: ElevatedButton.icon(
            onPressed: () => _deletePhoto(name),
            icon: const Icon(Icons.delete_outline_rounded, size: 14),
            label: const Text('Hapus', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error.withValues(alpha: 0.1), foregroundColor: AppTheme.error,
              elevation: 0, padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )),
        ])),
      ]),
    );
  }

  void _showPhotoPreview(BuildContext ctx, String url, String title) {
    showDialog(
      context: ctx,
      builder: (_) => _PhotoPreviewDialog(url: url, title: title),
    );
  }

  Future<void> _deleteOldPhotos(List<Map<String, dynamic>> oldPhotos) async {
    final confirm = await _confirmDialog(
      'Hapus Foto Lama',
      'Hapus ${oldPhotos.length} foto yang lebih dari $_photoDeleteValue $_photoDeleteUnit?\n\nTidak bisa dibatalkan.',
    );
    if (confirm != true) return;
    int deleted = 0;
    for (final p in oldPhotos) {
      final name = p['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final err = await SupabaseService.adminDeletePhoto(name);
      if (err == null) deleted++;
    }
    if (!mounted) return;
    _showSnack('$deleted foto lama dihapus');
    _loadPhotos();
  }

  Future<void> _deletePhoto(String fileName) async {
    final confirm = await _confirmDialog('Hapus Foto', 'Hapus "$fileName"?\n\nTidak bisa dibatalkan.');
    if (confirm != true) return;
    final error = await SupabaseService.adminDeletePhoto(fileName);
    if (!mounted) return;
    if (error != null) { _showSnack(error, isError: true); } else { _showSnack('Foto dihapus'); _loadPhotos(); }
  }

  // ═══════════════════════════════════════════════
  // SHARED: AUTO-DELETE & STORAGE CARDS
  // ═══════════════════════════════════════════════

  Widget _buildStorageCard() {
    const double maxBytes = 1024 * 1024 * 1024; // 1 GB (Supabase free tier limit)
    final double percent = (_totalStorageUsedBytes / maxBytes).clamp(0.0, 1.0);
    final usedMB = _totalStorageUsedBytes / (1024 * 1024);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF00BCD4).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.storage_rounded, color: Color(0xFF00BCD4), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kapasitas Server', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Batas gratis Supabase (1 GB)', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${usedMB.toStringAsFixed(1)} MB terpakai', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${(percent * 100).toStringAsFixed(1)}%', style: TextStyle(color: percent > 0.9 ? AppTheme.error : const Color(0xFF00BCD4), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 10,
            backgroundColor: AppTheme.surfaceDark,
            valueColor: AlwaysStoppedAnimation<Color>(percent > 0.9 ? AppTheme.error : (percent > 0.7 ? const Color(0xFFFF9800) : const Color(0xFF00BCD4))),
          ),
        ),
      ]),
    );
  }

  Widget _buildAutoDeleteCard({
    required IconData icon,
    required String title,
    required int value,
    required String unit,
    required int oldCount,
    required Future<void> Function(int, String) onSave,
    required VoidCallback onDeleteOld,
  }) {
    final valueCtrl = TextEditingController(text: value > 0 ? '$value' : '');
    final units = ['hari', 'minggu', 'bulan'];

    return StatefulBuilder(
      builder: (context, setCardState) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E2D3D), Color(0xFF162232)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_delete_rounded, color: const Color(0xFFE040FB), size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          const Text('Atur waktu otomatis hapus data lama', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
          const SizedBox(height: 12),
          // Input row: [angka] [unit selector] [tombol simpan]
          // Input row: [angka] [unit selector] [tombol simpan]
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Number input
              SizedBox(
                width: 60,
                height: 36,
                child: TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: const TextStyle(color: AppTheme.textHint),
                    filled: true, fillColor: AppTheme.surfaceDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.divider)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE040FB))),
                  ),
                ),
              ),
              // Unit chips
              ...units.map((u) {
                final isSelected = unit == u;
                return GestureDetector(
                  onTap: () {
                    final val = int.tryParse(valueCtrl.text) ?? 0;
                    onSave(val, u);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE040FB).withValues(alpha: 0.2) : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? const Color(0xFFE040FB) : AppTheme.divider),
                    ),
                    child: Text(u.substring(0, 1).toUpperCase() + u.substring(1),
                        style: TextStyle(color: isSelected ? const Color(0xFFE040FB) : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                );
              }),
              // Save button
              GestureDetector(
                onTap: () {
                  final val = int.tryParse(valueCtrl.text) ?? 0;
                  onSave(val, unit);
                  _showSnack(val > 0 ? 'Auto-delete: $val $unit' : 'Auto-delete nonaktif');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE040FB).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.save_rounded, color: Color(0xFFE040FB), size: 18),
                ),
              ),
            ],
          ),
          // Status & action
          if (value > 0 && oldCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: onDeleteOld,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: Text('Hapus $oldCount data lama sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error.withValues(alpha: 0.15), foregroundColor: AppTheme.error,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ],
          if (value > 0 && oldCount == 0) ...[
            const SizedBox(height: 8),
            Text('✅ Tidak ada data lebih dari $value $unit', style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
          ],
          if (value <= 0) ...[
            const SizedBox(height: 8),
            const Text('⏸ Auto-delete nonaktif. Masukkan angka dan pilih satuan.', style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
          ],
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // COMMON
  // ═══════════════════════════════════════════════

  Widget _buildLoading() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    CircularProgressIndicator(color: AppTheme.accent), SizedBox(height: 16),
    Text('Memuat data...', style: TextStyle(color: AppTheme.textSecondary)),
  ]));

  Future<bool?> _confirmDialog(String title, String message) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Lanjutkan', style: TextStyle(color: AppTheme.error))),
      ],
    ),
  );

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppTheme.error : const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ═══════════════════════════════════════════════
// Report Detail Sheet
// ═══════════════════════════════════════════════

class _ReportDetailSheet extends StatefulWidget {
  final String reportId;
  final int no;
  final List<Map<String, dynamic>> photos;
  const _ReportDetailSheet({required this.reportId, required this.no, required this.photos});

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  List<Map<String, dynamic>> _exams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exams = await SupabaseService.adminGetReportExams(widget.reportId);
    if (mounted) setState(() { _exams = exams; _loading = false; });
  }

  String _getValidPhotoUrl(Map<String, dynamic> exam) {
    String p = exam['foto_path'] as String? ?? '';
    if (p.startsWith('http')) return p;

    // Fallback: generate URL langsung dari examId (tidak perlu list photos)
    final examId = exam['id'] as String? ?? '';
    if (examId.isNotEmpty) {
      // Coba dari photos list yang sudah diload
      for (final photo in widget.photos) {
        final name = photo['name'] as String? ?? '';
        if (name.contains(examId)) {
          return photo['url'] as String? ?? '';
        }
      }
      // Fallback terakhir: generate URL langsung dari bucket
      return SupabaseService.getPhotoPublicUrl(examId) ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text('#${widget.no}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Laporan #${widget.no}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              Text('${_exams.length} Pasien', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ])),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE040FB)))
              : _exams.isEmpty
                ? const Center(child: Text('Tidak ada data pasien', style: TextStyle(color: AppTheme.textHint)))
                : ListView.builder(controller: scrollController, itemCount: _exams.length, itemBuilder: (_, i) => _card(_exams[i], i)),
          ),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> exam, int index) {
    final nama = exam['nama'] as String? ?? '-';
    final nik = exam['nik'] as String? ?? '';
    final tanggal = exam['tanggal'] as String? ?? '-';
    final tglLahir = exam['tanggal_lahir'] as String? ?? '';
    final usia = exam['usia'] as String? ?? '';
    final alamat = exam['alamat'] as String? ?? '';
    final tensi = exam['tensi'] as String? ?? '';
    final bb = exam['bb'] as String? ?? '';
    final tb = exam['tb'] as String? ?? '';
    final lp = exam['lingkar_pinggang'] as String? ?? '';
    final lila = exam['lila'] as String? ?? '';
    final lika = exam['lika'] as String? ?? '';
    final gd = exam['gula_darah'] as String? ?? '';
    final keluhan = List<String>.from(exam['keluhan'] as List? ?? []);
    final tindakLanjut = List<String>.from(exam['tindak_lanjut'] as List? ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nama, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            if (nik.isNotEmpty) Text('NIK: $nik', style: TextStyle(color: AppTheme.accentTeal.withValues(alpha: 0.8), fontSize: 11, fontFamily: 'monospace')),
          ])),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.accentTeal, size: 18),
            tooltip: 'Edit Data Pasien',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showEditExamDialog(exam),
          ),
        ]),
        const SizedBox(height: 8),
        _row('Tanggal', tanggal),
        if (tglLahir.isNotEmpty) _row('Tanggal Lahir', tglLahir),
        if (usia.isNotEmpty) _row('Usia', '$usia tahun'),
        if (alamat.isNotEmpty) _row('Alamat', alamat),
        if (tensi.isNotEmpty) _row('Tensi', tensi),
        if (bb.isNotEmpty) _row('BB', '$bb kg'),
        if (tb.isNotEmpty) _row('TB', '$tb cm'),
        if (lp.isNotEmpty) _row('LP', '$lp cm'),
        if (lila.isNotEmpty) _row('LILA', '$lila cm'),
        if (lika.isNotEmpty) _row('LIKA', '$lika cm'),
        if (gd.isNotEmpty) _row('Gula Darah', '$gd mg/dL'),
        if (keluhan.isNotEmpty) _row('Keluhan', keluhan.join(', ')),
        if (tindakLanjut.isNotEmpty) _row('Tindak Lanjut', tindakLanjut.join(', ')),
        // Foto thumbnail
        Builder(builder: (_) {
          final fotoUrl = _getValidPhotoUrl(exam);
          if (fotoUrl.isEmpty || !fotoUrl.startsWith('http')) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => showDialog(context: context, builder: (_) => _PhotoPreviewDialog(url: fotoUrl, title: nama)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(children: [
                  Image.network(fotoUrl, height: 120, width: double.infinity, fit: BoxFit.cover, cacheWidth: 400,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                  Positioned(bottom: 6, right: 6, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 3),
                      Text('Lihat', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ]),
                  )),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Future<void> _showEditExamDialog(Map<String, dynamic> exam) async {
    final examId = exam['id'] as String? ?? '';
    if (examId.isEmpty) return;

    // Controllers
    final namaCtrl = TextEditingController(text: exam['nama'] as String? ?? '');
    final nikCtrl = TextEditingController(text: exam['nik'] as String? ?? '');
    final tglCtrl = TextEditingController(text: exam['tanggal'] as String? ?? '');
    final tglLahirCtrl = TextEditingController(text: exam['tanggal_lahir'] as String? ?? '');
    final usiaCtrl = TextEditingController(text: exam['usia'] as String? ?? '');
    final alamatCtrl = TextEditingController(text: exam['alamat'] as String? ?? '');
    final tensiCtrl = TextEditingController(text: exam['tensi'] as String? ?? '');
    final bbCtrl = TextEditingController(text: exam['bb'] as String? ?? '');
    final tbCtrl = TextEditingController(text: exam['tb'] as String? ?? '');
    final lpCtrl = TextEditingController(text: exam['lingkar_pinggang'] as String? ?? '');
    final lilaCtrl = TextEditingController(text: exam['lila'] as String? ?? '');
    final likaCtrl = TextEditingController(text: exam['lika'] as String? ?? '');
    final gdCtrl = TextEditingController(text: exam['gula_darah'] as String? ?? '');
    final keluhanCtrl = TextEditingController(text: (exam['keluhan'] as List? ?? []).join(', '));
    final tindakCtrl = TextEditingController(text: (exam['tindak_lanjut'] as List? ?? []).join(', '));
    File? newFotoFile;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (ctx, scrollCtrl) => Column(children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF4CAF50)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edit Data Pasien', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(namaCtrl.text, style: TextStyle(color: AppTheme.accentTeal.withValues(alpha: 0.8), fontSize: 13)),
              ])),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: AppTheme.textHint)),
              ),
            ]),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          // Scrollable content
          Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), children: [
            // ── SECTION 1: Identitas Pasien ──
            _sectionHeader(Icons.person_rounded, 'Identitas Pasien', const Color(0xFF00BCD4)),
            const SizedBox(height: 10),
            _editField(namaCtrl, 'Nama Pasien', Icons.person_outline_rounded),
            const SizedBox(height: 10),
            _editField(nikCtrl, 'NIK', Icons.badge_rounded),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _editField(tglCtrl, 'Tanggal', Icons.calendar_today_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _editField(tglLahirCtrl, 'Tanggal Lahir', Icons.cake_outlined)),
            ]),
            const SizedBox(height: 10),
            _editField(usiaCtrl, 'Usia', Icons.cake_rounded),
            const SizedBox(height: 10),
            _editField(alamatCtrl, 'Alamat', Icons.location_on_outlined, maxLines: 2),

            const SizedBox(height: 20),
            // ── SECTION: Foto Pasien ──
            _sectionHeader(Icons.photo_camera_rounded, 'Foto Pasien', const Color(0xFFFF9800)),
            const SizedBox(height: 10),
            StatefulBuilder(builder: (ctx2, setPhoto) {
              final fotoUrl = _getValidPhotoUrl(exam);
              final hasCloud = fotoUrl.isNotEmpty && fotoUrl.startsWith('http');
              final hasNewFile = newFotoFile != null;

              return Column(children: [
                // Preview area
                Container(
                  height: hasCloud || hasNewFile ? 160 : 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                    color: AppTheme.surfaceDark,
                  ),
                  child: hasNewFile
                    ? GestureDetector(
                        onTap: () => showDialog(context: context, builder: (_) => _PhotoPreviewDialog(url: newFotoFile!.path, title: namaCtrl.text, isLocal: true)),
                        child: Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(newFotoFile!, fit: BoxFit.cover, width: double.infinity, height: 160),
                          ),
                          Positioned(top: 6, left: 6, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(6)),
                            child: const Text('FOTO BARU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          )),
                        ]),
                      )
                    : hasCloud
                      ? GestureDetector(
                          onTap: () => showDialog(context: context, builder: (_) => _PhotoPreviewDialog(url: fotoUrl, title: namaCtrl.text)),
                          child: Stack(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(fotoUrl, fit: BoxFit.cover, width: double.infinity, height: 160, cacheWidth: 400,
                                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.textHint, size: 40))),
                            ),
                            Positioned(bottom: 8, right: 8, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Lihat Foto', style: TextStyle(color: Colors.white, fontSize: 11)),
                              ]),
                            )),
                          ]),
                        )
                      : const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.image_not_supported_rounded, color: AppTheme.textHint, size: 20),
                          SizedBox(width: 8),
                          Text('Tidak ada foto', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                        ])),
                ),
                const SizedBox(height: 8),
                // Ganti Foto button
                SizedBox(
                  width: double.infinity, height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: context, backgroundColor: AppTheme.cardDark,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.accentTeal),
                            title: const Text('Kamera', style: TextStyle(color: AppTheme.textPrimary)),
                            onTap: () => Navigator.pop(c, ImageSource.camera)),
                          ListTile(leading: const Icon(Icons.photo_library_rounded, color: AppTheme.accentBlue),
                            title: const Text('Galeri', style: TextStyle(color: AppTheme.textPrimary)),
                            onTap: () => Navigator.pop(c, ImageSource.gallery)),
                        ])),
                      );
                      if (source == null) return;
                      final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
                      if (picked != null) {
                        setPhoto(() => newFotoFile = File(picked.path));
                      }
                    },
                    icon: Icon(hasNewFile ? Icons.check_circle_rounded : Icons.camera_alt_rounded, size: 16),
                    label: Text(hasNewFile ? 'Foto diganti ✓ Ketuk untuk ganti lagi' : 'Ganti Foto', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF9800),
                      side: BorderSide(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]);
            }),

            const SizedBox(height: 20),
            // ── SECTION 2: Hasil Pemeriksaan ──
            _sectionHeader(Icons.medical_services_rounded, 'Hasil Pemeriksaan', const Color(0xFF4CAF50)),
            const SizedBox(height: 10),
            _editField(tensiCtrl, 'Tensi', Icons.favorite_rounded),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _editField(bbCtrl, 'BB (kg)', Icons.monitor_weight_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _editField(tbCtrl, 'TB (cm)', Icons.height_rounded)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _editField(lpCtrl, 'LP (cm)', Icons.straighten_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _editField(lilaCtrl, 'LILA (cm)', Icons.accessibility_rounded)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _editField(likaCtrl, 'LIKA (cm)', Icons.circle_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _editField(gdCtrl, 'Gula Darah', Icons.water_drop_rounded)),
            ]),

            const SizedBox(height: 20),
            // ── SECTION 3: Catatan ──
            _sectionHeader(Icons.note_alt_rounded, 'Catatan', const Color(0xFFE040FB)),
            const SizedBox(height: 10),
            _editField(keluhanCtrl, 'Keluhan (pisahkan koma)', Icons.sick_rounded, maxLines: 3),
            const SizedBox(height: 10),
            _editField(tindakCtrl, 'Tindak Lanjut (pisahkan koma)', Icons.assignment_turned_in_rounded, maxLines: 3),

            const SizedBox(height: 24),
            // Save button
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.save_rounded, size: 20),
                label: const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ])),
        ]),
      ),
    );

    if (result != true) return;

    // Upload foto baru jika ada
    String? newFotoUrl;
    if (newFotoFile != null) {
      newFotoUrl = await SupabaseService.uploadPhoto(newFotoFile!.path, examId);
    }

    // Build update map
    final updates = <String, dynamic>{
      'nama': namaCtrl.text.trim(),
      'nik': nikCtrl.text.trim(),
      'tanggal': tglCtrl.text.trim(),
      'tanggal_lahir': tglLahirCtrl.text.trim(),
      'usia': usiaCtrl.text.trim(),
      'alamat': alamatCtrl.text.trim(),
      'tensi': tensiCtrl.text.trim(),
      'bb': bbCtrl.text.trim(),
      'tb': tbCtrl.text.trim(),
      'lingkar_pinggang': lpCtrl.text.trim(),
      'lila': lilaCtrl.text.trim(),
      'lika': likaCtrl.text.trim(),
      'gula_darah': gdCtrl.text.trim(),
      'keluhan': keluhanCtrl.text.trim().isEmpty ? [] : keluhanCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'tindak_lanjut': tindakCtrl.text.trim().isEmpty ? [] : tindakCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    };
    if (newFotoUrl != null) updates['foto_path'] = newFotoUrl;

    final error = await SupabaseService.adminUpdateExam(examId, updates);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.error));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newFotoUrl != null ? 'Data & foto berhasil diperbarui' : 'Data pasien berhasil diperbarui'), backgroundColor: const Color(0xFF4CAF50)),
      );
      _load();
    }
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.15))),
    ]);
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textHint, fontSize: 12),
        prefixIcon: Icon(icon, color: AppTheme.textHint, size: 18),
        filled: true, fillColor: AppTheme.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.5)),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.textHint, fontSize: 12))),
      Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
    ]),
  );
}

// ═══════════════════════════════════════════════
// Fullscreen Photo Preview with Zoom
// ═══════════════════════════════════════════════

class _PhotoPreviewDialog extends StatelessWidget {
  final String url;
  final String title;
  final bool isLocal;
  const _PhotoPreviewDialog({required this.url, required this.title, this.isLocal = false});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(children: [
        // Dark background
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(color: Colors.black87),
        ),
        // Zoomable image
        Center(
          child: InteractiveViewer(
            minScale: 0.5, maxScale: 5.0, clipBehavior: Clip.none,
            child: isLocal
                ? Image.file(File(url), fit: BoxFit.contain)
                : Image.network(url, fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator(color: AppTheme.accentTeal)),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.broken_image_rounded, color: AppTheme.textHint, size: 60),
                        SizedBox(height: 8),
                        Text('Gagal memuat foto', style: TextStyle(color: AppTheme.textHint)),
                      ]),
                    ),
                  ),
          ),
        ),
        // Header bar
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.black87, Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: Row(children: [
              const Icon(Icons.photo_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
        )),
        // Hint text
        Positioned(bottom: 40, left: 0, right: 0, child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
            child: const Text('Cubit untuk zoom • Ketuk luar untuk tutup', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ),
        )),
      ]),
    );
  }
}
