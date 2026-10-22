import 'package:flutter/material.dart';
import '../../models/user_session.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui/ui.dart';

/// Tab 3 Panel Admin: Kelola Foto Storage & Auto-Delete Foto
/// Desain sesuai mockups/main-canvas/AdminFoto.dc.html
class AdminFotoTab extends StatefulWidget {
  final UserSession session;
  final List<Map<String, dynamic>> photos;
  final bool loading;
  final int totalStorageUsedBytes;
  final int photoDeleteValue;
  final String photoDeleteUnit;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int value, String unit) onSavePhotoDelete;
  final Future<void> Function(String photoName) onDeletePhoto;
  final Future<void> Function(List<Map<String, dynamic>> oldPhotos)
      onDeleteOldPhotos;
  final void Function(BuildContext context, String url, String title)
      onPreviewPhoto;

  const AdminFotoTab({
    super.key,
    required this.session,
    required this.photos,
    required this.loading,
    required this.totalStorageUsedBytes,
    required this.photoDeleteValue,
    required this.photoDeleteUnit,
    required this.onRefresh,
    required this.onSavePhotoDelete,
    required this.onDeletePhoto,
    required this.onDeleteOldPhotos,
    required this.onPreviewPhoto,
  });

  @override
  State<AdminFotoTab> createState() => _AdminFotoTabState();
}

class _AdminFotoTabState extends State<AdminFotoTab> {
  late int _val;
  late String _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _val = widget.photoDeleteValue;
    _unit = widget.photoDeleteUnit;
  }

  @override
  void didUpdateWidget(AdminFotoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoDeleteValue != widget.photoDeleteValue ||
        oldWidget.photoDeleteUnit != widget.photoDeleteUnit) {
      _val = widget.photoDeleteValue;
      _unit = widget.photoDeleteUnit;
    }
  }

  int _unitToDays(int value, String unit) {
    if (value <= 0) return 0;
    switch (unit) {
      case 'hari':
        return value;
      case 'minggu':
        return value * 7;
      case 'bulan':
        return value * 30;
      default:
        return value * 30;
    }
  }

  Future<void> _updateSettings(int newVal, String newUnit) async {
    setState(() {
      _val = newVal;
      _unit = newUnit;
      _saving = true;
    });
    try {
      await widget.onSavePhotoDelete(newVal, newUnit);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(dynamic iso) {
    if (iso == null || iso.toString().isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso.toString());
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return iso.toString();
    }
  }

  String _formatSize(dynamic size) {
    if (size == null || size is! int || size <= 0) return '-';
    if (size > 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / 1024).toStringAsFixed(0)} KB';
  }

  String _displayName(String rawName) {
    // If name is like exam_uuid_timestamp.jpg or patient name
    final withoutExt = rawName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    if (withoutExt.length > 20) {
      return '${withoutExt.substring(0, 16)}...';
    }
    return withoutExt.isEmpty ? 'Foto Pasien' : withoutExt;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.photos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    final deleteDays = _unitToDays(_val, _unit);
    final oldPhotos = widget.photos.where((p) {
      if (deleteDays <= 0) return false;
      final ca = p['created_at'];
      if (ca == null || ca.toString().isEmpty) return false;
      try {
        return DateTime.now().difference(DateTime.parse(ca.toString())).inDays >
            deleteDays;
      } catch (_) {
        return false;
      }
    }).toList();

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  // ── 1. Storage Quota Card (AdminFoto.dc.html line 33) ──
                  _buildQuotaCard(),

                  const SizedBox(height: 12),

                  // ── 2. Auto-Delete Foto Card (AdminFoto.dc.html line 34) ──
                  _buildAutoDeleteCard(oldPhotos),

                  const SizedBox(height: 14),

                  // ── Section Title ──
                  Row(
                    children: [
                      Text(
                        'Galeri Foto (${widget.photos.length})',
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (oldPhotos.isNotEmpty)
                        Text(
                          '${oldPhotos.length} foto lama',
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // ── 3. Photo Grid (AdminFoto.dc.html line 35-37) ──
          if (widget.photos.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'Belum ada foto di penyimpanan cloud',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.80,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildPhotoCard(widget.photos[index], deleteDays),
                  childCount: widget.photos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuotaCard() {
    final usedMB = widget.totalStorageUsedBytes / (1024 * 1024);
    const double limitMB = 1024; // 1 GB free tier
    final percent = (usedMB / limitMB).clamp(0.0, 1.0);

    final statusText = percent > 0.9
        ? 'Penuh'
        : (percent > 0.7 ? 'Perhatian' : 'Aman');
    final statusColor = percent > 0.9
        ? AppTheme.error
        : (percent > 0.7 ? AppTheme.warning : AppTheme.success);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Penyimpanan foto',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: statusText,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar (AdminFoto.dc.html line 25)
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 10,
              color: AppTheme.surfaceRaised,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${usedMB.toStringAsFixed(1)} MB terpakai',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Text(
                'dari 1 GB',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDeleteCard(List<Map<String, dynamic>> oldPhotos) {
    final isEnabled = _val > 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hapus otomatis foto lama',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEnabled
                          ? 'Setelah $_val $_unit${oldPhotos.isNotEmpty ? ' · ${oldPhotos.length} foto akan terhapus' : ''}'
                          : 'Dihitung dari tanggal upload foto',
                      style: const TextStyle(
                        color: AppTheme.textFaint,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isEnabled,
                activeThumbColor: AppTheme.accent,
                activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
                onChanged: _saving
                    ? null
                    : (on) {
                        if (on) {
                          _updateSettings(2, _unit);
                        } else {
                          _updateSettings(0, _unit);
                        }
                      },
              ),
            ],
          ),

          if (isEnabled) ...[
            const SizedBox(height: 14),

            // Segmented Unit Tabs (Hari | Minggu | Bulan)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  _unitTab('Hari', 'hari'),
                  _unitTab('Minggu', 'minggu'),
                  _unitTab('Bulan', 'bulan'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Stepper: [-] Number [+]
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconCircleButton(
                  icon: Icons.remove_rounded,
                  onTap: _saving || _val <= 1
                      ? null
                      : () => _updateSettings(_val - 1, _unit),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    '$_val',
                    style: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _iconCircleButton(
                  icon: Icons.add_rounded,
                  onTap: _saving || _val >= 365
                      ? null
                      : () => _updateSettings(_val + 1, _unit),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Foto lebih tua dari $_val $_unit akan dihapus',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textFaint,
                fontSize: 13,
              ),
            ),

            if (oldPhotos.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const AppIcon(AppGlyph.warning, color: AppTheme.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${oldPhotos.length} foto melewati batas waktu.',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onDeleteOldPhotos(oldPhotos),
                      child: const Text(
                        'Hapus Sekarang',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _unitTab(String label, String value) {
    final active = _unit == value;
    return Expanded(
      child: GestureDetector(
        onTap: _saving ? null : () => _updateSettings(_val, value),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.decelerate,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? AppTheme.cardShadow : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.primaryDeep : AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconCircleButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: AppTheme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppTheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: enabled ? AppTheme.textMuted : AppTheme.textMuted.withValues(alpha: 0.3),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo, int deleteDays) {
    final name = photo['name'] as String? ?? '';
    final url = photo['url'] as String? ?? '';
    final size = photo['size'];
    final createdAt = photo['created_at'];

    final sizeStr = _formatSize(size);
    final dateStr = _formatDate(createdAt);
    final displayTitle = _displayName(name);

    bool isOld = false;
    if (createdAt != null && createdAt.toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt.toString());
        if (deleteDays > 0) {
          isOld = DateTime.now().difference(dt).inDays > deleteDays;
        }
      } catch (_) {}
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Photo Thumbnail / Fallback (AdminFoto.dc.html line 36) ──
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: url.isNotEmpty
                      ? () => widget.onPreviewPhoto(context, url, displayTitle)
                      : null,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised,
                      gradient: url.isEmpty
                          ? const LinearGradient(
                              colors: [Color(0xFF9FD0F2), Color(0xFF3F8FD0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: url.isNotEmpty
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            cacheWidth: 320,
                            errorBuilder: (_, __, ___) => const Center(
                              child: AppIcon(
                                AppGlyph.camera,
                                color: AppTheme.textMuted,
                                size: 28,
                              ),
                            ),
                          )
                        : const Center(
                            child: AppIcon(
                              AppGlyph.camera,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                  ),
                ),
                if (url.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const AppIcon(
                        AppGlyph.search,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                if (isOld)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LAMA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Photo Info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr · $sizeStr',
                        style: const TextStyle(
                          color: AppTheme.textFaint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus Foto',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const AppIcon(
                    AppGlyph.trash,
                    color: AppTheme.error,
                    size: 18,
                  ),
                  onPressed: () => widget.onDeletePhoto(name),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
