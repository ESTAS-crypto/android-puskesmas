import 'package:flutter/material.dart';
import '../../models/custom_role.dart';
import '../../models/user_session.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui/ui.dart';
import '../custom_roles_screen.dart';

class AdminUserTab extends StatefulWidget {
  final UserSession session;
  final List<Map<String, dynamic>> users;
  final Map<String, CustomRole> customRolesMap;
  final bool loading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String userId, String nama, String email, String puskesmas) onShowEditUser;
  final Future<void> Function(String targetUserId, String nama, String currentRole) onSetRole;
  final Future<void> Function(String email, String nama) onResetPassword;

  const AdminUserTab({
    super.key,
    required this.session,
    required this.users,
    required this.customRolesMap,
    required this.loading,
    required this.onRefresh,
    required this.onShowEditUser,
    required this.onSetRole,
    required this.onResetPassword,
  });

  @override
  State<AdminUserTab> createState() => _AdminUserTabState();
}

class _AdminUserTabState extends State<AdminUserTab> {
  String _searchQuery = '';
  late final TextEditingController _searchCtrl;
  bool _isMandatoryUpdate = false;
  bool _loadingMandatory = false;
  AppUpdateInfo? _latestConfig;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _loadMandatoryConfig();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMandatoryConfig() async {
    try {
      final config = await UpdateService.getLatestPublishedConfig();
      if (mounted) {
        setState(() {
          _latestConfig = config;
          _isMandatoryUpdate = config?.isMandatory ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleMandatoryUpdate(bool val) async {
    if (_latestConfig == null) {
      AppToast.show(
        context,
        'Belum ada versi rilis update di server. Rilis update terlebih dahulu.',
        kind: AppToastKind.warning,
      );
      return;
    }
    setState(() => _loadingMandatory = true);
    final err = await UpdateService.publishUpdate(
      version: _latestConfig!.version,
      versionCode: _latestConfig!.versionCode,
      downloadUrl: _latestConfig!.downloadUrl,
      releaseNotes: _latestConfig!.releaseNotes,
      isMandatory: val,
    );
    if (mounted) {
      setState(() {
        _loadingMandatory = false;
        if (err == null) {
          _isMandatoryUpdate = val;
        }
      });
      if (err == null) {
        AppToast.show(
          context,
          'Wajib update ${val ? "diaktifkan" : "dinonaktifkan"}',
          kind: AppToastKind.success,
        );
      } else {
        AppToast.show(
          context,
          'Gagal mengubah status wajib update: $err',
          kind: AppToastKind.error,
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return widget.users;
    final q = _searchQuery.toLowerCase();
    return widget.users.where((u) {
      final nama = (u['nama'] as String? ?? '').toLowerCase();
      final puskesmas = (u['puskesmas'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      final role = (u['role'] as String? ?? '').toLowerCase();
      final customRoleId = u['custom_role_id'] as String?;
      final customRoleName = (customRoleId != null && widget.customRolesMap.containsKey(customRoleId))
          ? widget.customRolesMap[customRoleId]!.name.toLowerCase()
          : '';
      return nama.contains(q) || puskesmas.contains(q) || email.contains(q) || role.contains(q) || customRoleName.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryDeep),
      );
    }

    final filtered = _filteredUsers;

    return RefreshIndicator(
      color: AppTheme.primaryDeep,
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // ── Search field (AdminUser.dc.html) ──
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppTheme.outline),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: AppTheme.text, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari nama atau puskesmas',
                hintStyle: const TextStyle(color: AppTheme.textFaint, fontSize: 15),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: AppIcon(AppGlyph.search, size: 20, color: AppTheme.textFaint),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),

          // ── Daftar User (AdminUser.dc.html) ──
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const AppIcon(AppGlyph.users, size: 48, color: AppTheme.textFaint),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isEmpty ? 'Belum ada data user' : 'User tidak ditemukan',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((user) => _buildUserCard(user)),

          const SizedBox(height: 12),

          // ── Tombol Kelola Role Custom (AdminUser.dc.html line 39) ──
          if (widget.session.isDeveloper)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomRolesScreen(session: widget.session),
                      ),
                    ).then((_) => widget.onRefresh());
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(AppGlyph.shield, size: 20, color: AppTheme.primaryDeep),
                        SizedBox(width: 8),
                        Text(
                          'Kelola role custom',
                          style: TextStyle(
                            color: AppTheme.primaryDeep,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Card Wajib Update Aplikasi (AdminUser.dc.html line 40) ──
          if (widget.session.isDeveloper)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wajib update aplikasi',
                          style: TextStyle(
                            color: AppTheme.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pengguna tidak bisa melewati dialog update',
                          style: TextStyle(
                            color: AppTheme.textFaint,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loadingMandatory)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryDeep),
                    )
                  else
                    Switch(
                      value: _isMandatoryUpdate,
                      onChanged: _toggleMandatoryUpdate,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppTheme.primaryDeep,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final nama = user['nama'] as String? ?? 'Tanpa Nama';
    final email = user['email'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final puskesmas = user['puskesmas'] as String? ?? '';
    final role = user['role'] as String? ?? 'user';
    final userId = user['id'] as String? ?? '';
    final customRoleId = user['custom_role_id'] as String?;
    final isCurrentUser = userId == widget.session.userId;
    final initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

    CustomRole? customRole;
    if (customRoleId != null && widget.customRolesMap.containsKey(customRoleId)) {
      customRole = widget.customRolesMap[customRoleId];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar chip bulat
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.primaryDeep,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Nama & Puskesmas
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nama,
                          style: const TextStyle(
                            color: AppTheme.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDeep.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Anda',
                            style: TextStyle(color: AppTheme.primaryDeep, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    puskesmas.isNotEmpty ? 'PKM $puskesmas' : (email.isNotEmpty ? email : '@$username'),
                    style: const TextStyle(color: AppTheme.textFaint, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Role Pill (Custom Role atau Built-In)
            _buildRolePill(role, customRole),

            // Popup menu aksi
            PopupMenuButton<String>(
              color: AppTheme.surface,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
              onSelected: (val) {
                if (val == 'edit') {
                  widget.onShowEditUser(userId, nama, email, puskesmas);
                } else if (val == 'set_role') {
                  widget.onSetRole(userId, nama, role);
                } else if (val == 'reset_pw') {
                  widget.onResetPassword(email, nama);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      AppIcon(AppGlyph.edit, color: AppTheme.primaryDeep, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Profil', style: TextStyle(color: AppTheme.text, fontSize: 14)),
                    ],
                  ),
                ),
                if (!isCurrentUser && widget.session.canModifyRole(role))
                  const PopupMenuItem(
                    value: 'set_role',
                    child: Row(
                      children: [
                        AppIcon(AppGlyph.shield, color: AppTheme.warning, size: 18),
                        SizedBox(width: 10),
                        Text('Ubah Role', style: TextStyle(color: AppTheme.text, fontSize: 14)),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'reset_pw',
                  child: Row(
                    children: [
                      AppIcon(AppGlyph.lock, color: AppTheme.textMuted, size: 18),
                      SizedBox(width: 10),
                      Text('Reset Password', style: TextStyle(color: AppTheme.text, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePill(String role, CustomRole? customRole) {
    if (customRole != null) {
      final color = Color(customRole.colorValue);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          customRole.name,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    Color color;
    Color bg;
    String label;

    switch (role) {
      case 'owner':
        color = const Color(0xFF8A5200);
        bg = const Color(0xFFB06A00).withValues(alpha: 0.12);
        label = 'Owner';
        break;
      case 'developer':
        color = AppTheme.primaryDeep;
        bg = AppTheme.primaryDeep.withValues(alpha: 0.10);
        label = 'Developer';
        break;
      case 'admin':
        color = AppTheme.primaryDeep;
        bg = AppTheme.primaryDeep.withValues(alpha: 0.10);
        label = 'Admin';
        break;
      default:
        color = AppTheme.textMuted;
        bg = AppTheme.textMuted.withValues(alpha: 0.10);
        label = 'User';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
