import 'package:flutter/material.dart';
import '../models/custom_role.dart';
import '../models/user_session.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary, size: 20),
        ),
        title: const Row(children: [
          Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 22),
          SizedBox(width: 8),
          Text('Kelola Role Custom', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            onPressed: _loadRoles,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textHint),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleDialog(null),
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Buat Role', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _roles.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  color: const Color(0xFFFFD700),
                  onRefresh: _loadRoles,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _roles.length,
                    itemBuilder: (_, i) => _buildRoleCard(_roles[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 40),
        ),
        const SizedBox(height: 16),
        const Text('Belum ada role custom', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Tekan tombol + untuk membuat role baru', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
      ]),
    );
  }

  Widget _buildRoleCard(CustomRole role) {
    final color = Color(role.colorValue);
    final icon = _getIconData(role.iconName);
    final permLabels = _buildPermLabels(role.permissions);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role.name, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('${permLabels.length} permission aktif', style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
            ])),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textHint),
              color: AppTheme.cardDark,
              onSelected: (v) {
                if (v == 'edit') _showRoleDialog(role);
                if (v == 'delete') _confirmDelete(role);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_rounded, color: AppTheme.accentTeal, size: 18), SizedBox(width: 8),
                  Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 18), SizedBox(width: 8),
                  Text('Hapus', style: TextStyle(color: AppTheme.error)),
                ])),
              ],
            ),
          ]),
          if (permLabels.isNotEmpty) ...[ 
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: permLabels.map((label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            )).toList()),
          ],
        ]),
      ),
    );
  }

  List<String> _buildPermLabels(int perms) {
    final labels = <String>[];
    if (perms & CustomRole.permViewAll != 0) labels.add('Lihat Semua Laporan');
    if (perms & CustomRole.permExport != 0) labels.add('Export PDF/DOCX');
    if (perms & CustomRole.permManageUsers != 0) labels.add('Kelola User');
    if (perms & CustomRole.permDeleteReport != 0) labels.add('Hapus Laporan');
    if (perms & CustomRole.permGlobalMode != 0) labels.add('Mode Global');
    if (perms & CustomRole.permAdminPanel != 0) labels.add('Admin Panel');
    return labels;
  }

  Future<void> _confirmDelete(CustomRole role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.warning_rounded, color: AppTheme.error, size: 22),
          const SizedBox(width: 8),
          Text('Hapus Role "${role.name}"?', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
        ]),
        content: const Text('Role yang dihapus tidak bisa dikembalikan. User dengan role ini akan kehilangan akses custom-nya.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final error = await SupabaseService.deleteCustomRole(role.id);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('Role "${role.name}" dihapus');
      _loadRoles();
    }
  }

  Future<void> _showRoleDialog(CustomRole? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int selectedColor = existing?.colorValue ?? 0xFFE040FB;
    String selectedIcon = existing?.iconName ?? 'person_rounded';
    int permissions = existing?.permissions ?? 0;

    final colorOptions = <int>[
      0xFFE040FB, // violet
      0xFF00E5FF, // cyan
      0xFFFFD700, // gold
      0xFF4CAF50, // green
      0xFFFF6B6B, // red
      0xFF448AFF, // blue
      0xFFFF9800, // orange
      0xFFAB47BC, // purple
    ];

    final iconOptions = <String>[
      'person_rounded', 'supervisor_account', 'manage_accounts_rounded',
      'admin_panel_settings_rounded', 'star_rounded', 'verified_rounded',
      'security_rounded', 'local_hospital_rounded', 'school_rounded',
      'work_rounded', 'groups_rounded', 'badge_rounded',
    ];

    final permBits = [
      CustomRole.permViewAll,
      CustomRole.permExport,
      CustomRole.permManageUsers,
      CustomRole.permDeleteReport,
      CustomRole.permGlobalMode,
      CustomRole.permAdminPanel,
    ];
    final permNames = ['Lihat Semua Laporan', 'Export PDF/DOCX', 'Kelola User', 'Hapus Laporan', 'Mode Global', 'Admin Panel'];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Color(selectedColor).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_getIconData(selectedIcon), color: Color(selectedColor), size: 24),
                ),
                const SizedBox(width: 12),
                Text(existing == null ? 'Buat Role Baru' : 'Edit Role', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 20),

              // Nama role
              _label('Nama Role'),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'contoh: Supervisor, Koordinator...',
                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                  filled: true, fillColor: AppTheme.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.divider)),
                ),
              ),
              const SizedBox(height: 18),

              // Warna
              _label('Warna Role'),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: colorOptions.map((c) {
                final isSelected = c == selectedColor;
                return GestureDetector(
                  onTap: () => setDialog(() => selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected ? [BoxShadow(color: Color(c).withValues(alpha: 0.6), blurRadius: 8)] : null,
                    ),
                    child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList()),
              const SizedBox(height: 18),

              // Ikon
              _label('Ikon Role'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: iconOptions.map((iName) {
                final isSelected = iName == selectedIcon;
                return GestureDetector(
                  onTap: () => setDialog(() => selectedIcon = iName),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? Color(selectedColor).withValues(alpha: 0.2) : AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: Color(selectedColor), width: 2) : Border.all(color: AppTheme.divider),
                    ),
                    child: Icon(_getIconData(iName), color: isSelected ? Color(selectedColor) : AppTheme.textHint, size: 22),
                  ),
                );
              }).toList()),
              const SizedBox(height: 18),

              // Permissions
              _label('Permission Akses'),
              const SizedBox(height: 6),
              ...List.generate(permBits.length, (i) {
                final bit = permBits[i];
                final active = permissions & bit != 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: active ? Color(selectedColor).withValues(alpha: 0.08) : AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? Color(selectedColor).withValues(alpha: 0.4) : AppTheme.divider),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    title: Text(permNames[i], style: TextStyle(color: active ? Color(selectedColor) : AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    value: active,
                    activeThumbColor: Color(selectedColor),
                    inactiveThumbColor: AppTheme.textHint,
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return Color(selectedColor).withValues(alpha: 0.3);
                      return AppTheme.divider;
                    }),
                    onChanged: (v) => setDialog(() {
                      if (v) {
                        permissions |= bit;
                      } else {
                        permissions &= ~bit;
                      }
                    }),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Actions
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama role tidak boleh kosong')));
                      return;
                    }
                    Navigator.pop(ctx);
                    String? error;
                    if (existing == null) {
                      error = await SupabaseService.createCustomRole(
                        name: name, colorValue: selectedColor,
                        iconName: selectedIcon, permissions: permissions,
                        createdBy: widget.session.userId,
                      );
                    } else {
                      error = await SupabaseService.updateCustomRole(
                        roleId: existing.id, name: name, colorValue: selectedColor,
                        iconName: selectedIcon, permissions: permissions,
                      );
                    }
                    if (!mounted) return;
                    if (error != null) {
                      _showSnack(error, isError: true);
                    } else {
                      _showSnack(existing == null ? 'Role "$name" berhasil dibuat' : 'Role "$name" diperbarui');
                      _loadRoles();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(selectedColor),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(existing == null ? 'Buat Role' : 'Simpan', style: const TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));
  }

  IconData _getIconData(String name) {
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
}

/// Helper function to get IconData — used in other screens too.
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
