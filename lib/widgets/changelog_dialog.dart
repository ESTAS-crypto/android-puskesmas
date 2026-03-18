import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ChangelogDialog {
  static const String _currentVersion = '2.1.0';
  static const String _seenVersionKey = 'changelog_seen_version';

  static final List<Map<String, dynamic>> _changelog = [
    {
      'version': '2.1.0',
      'date': '16 Maret 2026',
      'changes': [
        {'icon': Icons.add_circle_outline, 'text': 'Custom pengukuran — buat field sendiri di Data Pengukuran', 'type': 'new'},
        {'icon': Icons.description_outlined, 'text': 'DOCX bisa dibuka di MS Word Android', 'type': 'fix'},
        {'icon': Icons.animation, 'text': 'Splash screen lebih cepat & mulus', 'type': 'improve'},
        {'icon': Icons.cleaning_services, 'text': 'File tidak perlu dihapus, app lebih ringan', 'type': 'improve'},
      ],
    },
    {
      'version': '2.0.0',
      'date': '28 Februari 2026',
      'changes': [
        {'icon': Icons.rocket_launch, 'text': 'Rilis pertama v2 dengan desain baru', 'type': 'new'},
        {'icon': Icons.picture_as_pdf, 'text': 'Export PDF & DOCX', 'type': 'new'},
        {'icon': Icons.mic, 'text': 'Voice input untuk semua field', 'type': 'new'},
        {'icon': Icons.wifi_off, 'text': '100% Offline — tanpa internet', 'type': 'new'},
      ],
    },
  ];

  /// Check if changelog should auto-show (new version detected)
  static Future<bool> shouldShowChangelog() async {
    final prefs = await SharedPreferences.getInstance();
    final seenVersion = prefs.getString(_seenVersionKey);
    return seenVersion != _currentVersion;
  }

  /// Mark current version as seen
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenVersionKey, _currentVersion);
  }

  /// Show the changelog dialog
  static Future<void> show(BuildContext context, {bool isAutoShow = false}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.new_releases_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yang Baru',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Changelog & Update',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _changelog.map((version) {
                      final isLatest = version['version'] == _currentVersion;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Version header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: isLatest ? AppTheme.primaryGradient : null,
                                    color: isLatest ? null : AppTheme.surfaceDark,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'v${version['version']}',
                                    style: TextStyle(
                                      color: isLatest ? Colors.white : AppTheme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isLatest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'TERBARU',
                                      style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  version['date'] as String,
                                  style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Changes list
                            ...((version['changes'] as List<Map<String, dynamic>>).map((change) {
                              Color iconColor;
                              switch (change['type']) {
                                case 'new':
                                  iconColor = AppTheme.accentTeal;
                                  break;
                                case 'fix':
                                  iconColor = AppTheme.warning;
                                  break;
                                case 'improve':
                                  iconColor = AppTheme.accentBlue;
                                  break;
                                default:
                                  iconColor = AppTheme.textSecondary;
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(change['icon'] as IconData, color: iconColor, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        change['text'] as String,
                                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })),
                            if (version != _changelog.last)
                              Divider(color: AppTheme.divider, height: 20),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      await markAsSeen();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isAutoShow ? 'Mengerti 👍' : 'Tutup',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // If auto-show, mark as seen when dialog is dismissed
    if (isAutoShow) {
      await markAsSeen();
    }
  }
}
