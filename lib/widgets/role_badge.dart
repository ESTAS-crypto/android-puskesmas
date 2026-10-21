import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../models/custom_role.dart';
import '../theme/app_theme.dart';
import '../screens/custom_roles_screen.dart' show getCustomRoleIconData;

/// Widget badge yang menampilkan role pengguna dengan warna & ikon yang sesuai.
/// Mendukung role bawaan (owner, developer, admin, user) dan role custom.
class RoleBadge extends StatelessWidget {
  final UserSession session;
  final bool compact; // jika true, hanya tampilkan ikon tanpa teks

  const RoleBadge({super.key, required this.session, this.compact = false});

  // ── Definisi tampilan per role ──────────────────────────────────────────────

  static RoleStyle _styleForRole(String role) {
    switch (role) {
      case 'owner':
        return RoleStyle(
          label: 'Owner',
          icon: Icons.auto_awesome_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
          glowColor: const Color(0xFFFFD700),
        );
      case 'developer':
        return RoleStyle(
          label: 'Developer',
          icon: Icons.code_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
          ),
          glowColor: const Color(0xFF00B4DB),
        );
      case 'admin':
        return RoleStyle(
          label: 'Admin',
          icon: Icons.admin_panel_settings_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF448AFF), Color(0xFF00BCD4)],
          ),
          glowColor: const Color(0xFF448AFF),
        );
      default:
        return RoleStyle(
          label: 'Kader',
          icon: Icons.person_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF546E7A), Color(0xFF78909C)],
          ),
          glowColor: const Color(0xFF546E7A),
        );
    }
  }

  /// Buat RoleStyle dari CustomRole
  static RoleStyle _styleForCustomRole(CustomRole cr) {
    final color = Color(cr.colorValue);
    return RoleStyle(
      label: cr.name,
      icon: getCustomRoleIconData(cr.iconName),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.8), color],
      ),
      glowColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Jika ada custom role, tampilkan custom role badge (menggantikan badge bawaan)
    final cr = session.customRole;
    final style = cr != null ? _styleForCustomRole(cr) : _styleForRole(session.role);

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: style.gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: style.glowColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(style.icon, color: Colors.white, size: 12),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: style.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: style.glowColor.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            style.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data tampilan untuk setiap role.
class RoleStyle {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final Color glowColor;

  const RoleStyle({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glowColor,
  });
}

/// Widget header dashboard dengan sapaan + badge role yang premium.
class DashboardHeader extends StatelessWidget {
  final UserSession session;
  final VoidCallback onChangelogTap;
  final VoidCallback onLogoutTap;
  final VoidCallback? onUpdateTap;

  const DashboardHeader({
    super.key,
    required this.session,
    required this.onChangelogTap,
    required this.onLogoutTap,
    this.onUpdateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar + nama + role
        Expanded(
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${session.nama.split(' ').first} 👋',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RoleBadge(session: session),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Action buttons
        if (onUpdateTap != null) ...[
          _buildIconBtn(Icons.system_update_rounded, AppTheme.accentBlue, onUpdateTap!),
          const SizedBox(width: 8),
        ],
        _buildIconBtn(Icons.new_releases_outlined, AppTheme.accentTeal, onChangelogTap),
        const SizedBox(width: 8),
        _buildIconBtn(Icons.logout_rounded, AppTheme.textSecondary, onLogoutTap),
      ],
    );
  }

  Widget _buildAvatar() {
    final initial = session.nama.isNotEmpty ? session.nama[0].toUpperCase() : '?';
    // Use custom role style for avatar if custom role is present
    final cr = session.customRole;
    final style = cr != null
        ? RoleBadge._styleForCustomRole(cr)
        : RoleBadge._styleForRole(session.role);

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: style.gradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: style.glowColor.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
