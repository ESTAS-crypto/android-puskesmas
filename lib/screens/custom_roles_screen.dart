import 'package:flutter/material.dart';
import '../models/custom_role.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/ui.dart';

class CustomRolesScreen extends StatefulWidget {
  final UserSession session;
  const CustomRolesScreen({super.key, required this.session});

  @override
  State<CustomRolesScreen> createState() => _CustomRolesScreenState();
}

class _CustomRolesScreenState extends State<CustomRolesScreen> {
  List<CustomRole> _roles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _loading = true);
    final maps = await SupabaseService.getCustomRoles();
    if (mounted) {
      setState(() {
        _roles = maps.map((m) => CustomRole.fromMap(m)).toList();
        _loading = false;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    AppToast.show(
      context,
      msg,
      kind: isError ? AppToastKind.error : AppToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD6ECFA), Color(0xFFF1F8FD)],
            stops: [0.0, 0.45],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: const AppIcon(
                          AppGlyph.back,
                          size: 20,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Kelola role custom',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Segarkan',
                      onPressed: _loadRoles,
                      icon: const AppIcon(
                        AppGlyph.update,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryDeep,
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryDeep,
                        onRefresh: _loadRoles,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          children: [
                            // "Buat role" Primary Button
                            AppButton(
                              label: 'Buat role',
                              icon: AppGlyph.plus,
                              kind: AppButtonKind.primary,
                              onPressed: () => _showRoleSheet(null),
                            ),
                            const SizedBox(height: 16),

                            if (_roles.isEmpty)
                              _buildEmpty()
                            else
                              ..._roles.map((role) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildRoleCard(role),
                                  )),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.tint(AppTheme.primaryDeep, 0.10),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: AppIcon(
                  AppGlyph.shield,
                  color: AppTheme.primaryDeep,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada role custom',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tekan tombol "Buat role" di atas untuk menambahkan role baru.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(CustomRole role) {
    final color = Color(role.colorValue);
    final icon = getCustomRoleIconData(role.iconName);
    final permLabels = _buildPermLabels(role.permissions);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(11, 42, 64, 0.06),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color.fromRGBO(10, 100, 168, 0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${permLabels.length} permission aktif',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),

          // Permission pills
          if (permLabels.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: permLabels.map((label) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A64A8).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF0A64A8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ] else
            const SizedBox(height: 12),

          // Action row: Edit & Hapus buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Edit',
                  kind: AppButtonKind.tonal,
                  onPressed: () => _showRoleSheet(role),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Hapus',
                  kind: AppButtonKind.danger,
                  onPressed: () => _confirmDelete(role),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _buildPermLabels(int perms) {
    final labels = <String>[];
    if (perms & CustomRole.permViewAll != 0) labels.add('Lihat laporan');
    if (perms & CustomRole.permExport != 0) labels.add('Cetak & Export');
    if (perms & CustomRole.permManageUsers != 0) labels.add('Kelola user');
    if (perms & CustomRole.permDeleteReport != 0) labels.add('Hapus laporan');
    if (perms & CustomRole.permGlobalMode != 0) {
      labels.add('Lihat semua puskesmas');
    }
    if (perms & CustomRole.permAdminPanel != 0) labels.add('Panel admin');
    return labels;
  }

  Future<void> _confirmDelete(CustomRole role) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Hapus Role "${role.name}"?',
      message:
          'Role yang dihapus tidak bisa dikembalikan. Pengguna dengan role ini akan kehilangan akses khususnya.',
      confirmLabel: 'Hapus',
      cancelLabel: 'Batal',
      isDangerous: true,
    );
    if (!confirmed) return;

    final error = await SupabaseService.deleteCustomRole(role.id);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('Role "${role.name}" berhasil dihapus');
      _loadRoles();
    }
  }

  Future<void> _showRoleSheet(CustomRole? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int selectedColor = existing?.colorValue ?? 0xFF0A64A8;
    String selectedIcon = existing?.iconName ?? 'person_rounded';
    int permissions = existing?.permissions ?? 0;

    final colorOptions = <int>[
      0xFF0A64A8, // Biru laut (Primary)
      0xFF2E9C6A, // Hijau Sehat (Emerald)
      0xFFB06A00, // Kuning/Amber
      0xFF6B5BD6, // Ungu / Violet
      0xFF00BCD4, // Cyan
      0xFFD32F2F, // Merah
      0xFFE91E63, // Magenta
      0xFF455A64, // Slate
    ];

    final iconOptions = <String>[
      'person_rounded',
      'supervisor_account',
      'manage_accounts_rounded',
      'admin_panel_settings_rounded',
      'star_rounded',
      'verified_rounded',
      'security_rounded',
      'local_hospital_rounded',
      'school_rounded',
      'work_rounded',
      'groups_rounded',
      'badge_rounded',
    ];

    final permDefs = [
      (CustomRole.permViewAll, 'Lihat laporan', 'Dapat melihat semua data laporan'),
      (CustomRole.permExport, 'Cetak & Export', 'Dapat mencetak dan mengunduh PDF/DOCX'),
      (CustomRole.permManageUsers, 'Kelola user', 'Dapat mengatur akun pengguna puskesmas'),
      (CustomRole.permDeleteReport, 'Hapus laporan', 'Dapat menghapus data laporan'),
      (CustomRole.permGlobalMode, 'Lihat semua puskesmas', 'Akses laporan lintas faskes (mode global)'),
      (CustomRole.permAdminPanel, 'Panel admin', 'Akses penuh ke menu administrasi'),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(11, 42, 64, 0.14),
                blurRadius: 30,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(selectedColor),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        existing == null ? 'Role baru' : 'Edit role',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nama Role
                const Text(
                  'Nama role',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: TextField(
                    controller: nameCtrl,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'contoh: Supervisor wilayah',
                      hintStyle: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Warna Label
                const Text(
                  'Warna label',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: colorOptions.map((c) {
                      final isSelected = c == selectedColor;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => setSheet(() => selectedColor = c),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(c),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(c),
                                        spreadRadius: 2,
                                        blurRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Ikon Role
                const Text(
                  'Ikon role',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: iconOptions.map((iName) {
                    final isSelected = iName == selectedIcon;
                    return GestureDetector(
                      onTap: () => setSheet(() => selectedIcon = iName),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(selectedColor).withValues(alpha: 0.15)
                              : const Color(0xFFEAF3FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Color(selectedColor)
                                : AppTheme.divider,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Icon(
                          getCustomRoleIconData(iName),
                          color: isSelected
                              ? Color(selectedColor)
                              : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.divider, height: 1),
                const SizedBox(height: 14),

                // Permissions switch rows
                const Text(
                  'Permission akses',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ...permDefs.map((def) {
                  final bit = def.$1;
                  final title = def.$2;
                  final subtitle = def.$3;
                  final active = permissions & bit != 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: active,
                          activeThumbColor: Color(selectedColor),
                          activeTrackColor:
                              Color(selectedColor).withValues(alpha: 0.35),
                          onChanged: (v) => setSheet(() {
                            if (v) {
                              permissions |= bit;
                            } else {
                              permissions &= ~bit;
                            }
                          }),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Submit Button
                AppButton(
                  label: existing == null ? 'Simpan role' : 'Perbarui role',
                  kind: AppButtonKind.primary,
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      AppToast.show(
                        context,
                        'Nama role tidak boleh kosong',
                        kind: AppToastKind.error,
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    String? error;
                    if (existing == null) {
                      error = await SupabaseService.createCustomRole(
                        name: name,
                        colorValue: selectedColor,
                        iconName: selectedIcon,
                        permissions: permissions,
                        createdBy: widget.session.userId,
                      );
                    } else {
                      error = await SupabaseService.updateCustomRole(
                        roleId: existing.id,
                        name: name,
                        colorValue: selectedColor,
                        iconName: selectedIcon,
                        permissions: permissions,
                      );
                    }
                    if (!mounted) return;
                    if (error != null) {
                      _showSnack(error, isError: true);
                    } else {
                      _showSnack(existing == null
                          ? 'Role "$name" berhasil dibuat'
                          : 'Role "$name" berhasil diperbarui');
                      _loadRoles();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to get IconData — used across the app (Admin Panel, History, RoleBadge).
IconData getCustomRoleIconData(String name) {
  const map = <String, IconData>{
    'person_rounded': Icons.person_rounded,
    'supervisor_account': Icons.supervisor_account,
    'manage_accounts_rounded': Icons.manage_accounts_rounded,
    'admin_panel_settings_rounded': Icons.admin_panel_settings_rounded,
    'star_rounded': Icons.star_rounded,
    'verified_rounded': Icons.verified_rounded,
    'security_rounded': Icons.security_rounded,
    'local_hospital_rounded': Icons.local_hospital_rounded,
    'school_rounded': Icons.school_rounded,
    'work_rounded': Icons.work_rounded,
    'groups_rounded': Icons.groups_rounded,
    'badge_rounded': Icons.badge_rounded,
  };
  return map[name] ?? Icons.person_rounded;
}
