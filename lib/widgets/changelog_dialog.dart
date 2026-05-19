import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ChangelogDialog {
  static const String _currentVersion = '2.7.0';
  static const String _seenVersionKey = 'changelog_seen_version';

  static final List<Map<String, dynamic>> _changelog = [
    {
      'version': '2.7.0',
      'date': '19 Mei 2026',
      'changes': [
        {'icon': Icons.manage_accounts_rounded, 'text': '🔑 Sistem role baru: Owner › Developer › Admin › User — setiap level punya batas wewenang sendiri', 'type': 'new'},
        {'icon': Icons.shield_rounded, 'text': '🛡️ Admin sekarang tidak bisa mengubah role siapapun — hanya Developer/Owner yang bisa kelola role', 'type': 'new'},
        {'icon': Icons.no_accounts_rounded, 'text': '🚫 Admin tidak bisa menurunkan atau menghapus akun yang rolenya lebih tinggi dari dirinya', 'type': 'new'},
        {'icon': Icons.refresh_rounded, 'text': '🔄 Role akan otomatis diperbarui saat aplikasi dibuka — tidak perlu logout dulu!', 'type': 'fix'},
        {'icon': Icons.badge_rounded, 'text': '🎨 Badge role kini berwarna berbeda: Emas (Owner), Cyan (Developer), Ungu (Admin)', 'type': 'improve'},
      ],
    },
    {
      'version': '2.6.0',
      'date': '20 April 2026',
      'changes': [
        {'icon': Icons.g_mobiledata_rounded, 'text': '✨ Sekarang bisa masuk pakai akun Gmail — tidak perlu buat akun baru lagi!', 'type': 'new'},
        {'icon': Icons.badge_rounded, 'text': '📝 Masuk pertama kali lewat Google? Tinggal isi nama kader & puskesmas, lalu selesai!', 'type': 'new'},
        {'icon': Icons.auto_delete_rounded, 'text': '🧹 Foto & laporan lama di HP otomatis terhapus sendiri — HP tidak bakal penuh!', 'type': 'new'},
        {'icon': Icons.cloud_off_rounded, 'text': '☁️ Data lama di server juga ikut dibersihkan sendiri setiap kali admin buka aplikasi', 'type': 'new'},
        {'icon': Icons.speed_rounded, 'text': '⚡ Aplikasi terasa lebih ringan & cepat saat dibuka', 'type': 'improve'},
        {'icon': Icons.error_outline_rounded, 'text': '💬 Kalau ada masalah saat login, pesannya sekarang lebih mudah dimengerti', 'type': 'improve'},
      ],
    },
    {
      'version': '2.5.0',
      'date': '27 Maret 2026',
      'changes': [
        {'icon': Icons.cloud_sync_rounded, 'text': '☁️ Data tersimpan ke internet — bisa dilihat dari HP mana saja!', 'type': 'new'},
        {'icon': Icons.login_rounded, 'text': '🔐 Masuk bisa pakai nama pengguna atau alamat email — pilih yang paling ingat', 'type': 'new'},
        {'icon': Icons.pin_rounded, 'text': '🔢 Lupa kata sandi? Bisa diubah lewat kode 6 angka yang dikirim ke email', 'type': 'new'},
        {'icon': Icons.public_rounded, 'text': '🔍 Bisa cari data pasien dari semua petugas puskesmas (butuh internet)', 'type': 'new'},
        {'icon': Icons.wifi_rounded, 'text': '📶 Ada tanda di layar apakah HP sedang terkoneksi internet atau tidak', 'type': 'new'},
        {'icon': Icons.person_add_rounded, 'text': '👤 Daftar akun baru kini lebih aman — ada konfirmasi ke email', 'type': 'new'},
        {'icon': Icons.search_rounded, 'text': '🔍 Cari pasien sekarang bisa pakai nomor NIK', 'type': 'improve'},
      ],
    },
    {
      'version': '2.4.0',
      'date': '19 Maret 2026',
      'changes': [
        {'icon': Icons.badge_rounded, 'text': '🪪 Ditambahkan kolom Nomor NIK di data pasien', 'type': 'new'},
        {'icon': Icons.share_rounded, 'text': '📤 Laporan bisa langsung dikirim ke WhatsApp atau aplikasi lain dari HP', 'type': 'new'},
        {'icon': Icons.drag_handle_rounded, 'text': '↕️ Urutan keluhan & tindakan bisa diubah dengan cara digeser-geser', 'type': 'new'},
        {'icon': Icons.edit_document, 'text': '✏️ Tulisan "Warga" sudah diganti menjadi "Pasien" di seluruh aplikasi', 'type': 'improve'},
      ],
    },
    {
      'version': '2.3.0',
      'date': '15 Maret 2026',
      'changes': [
        {'icon': Icons.calendar_month_rounded, 'text': '📅 Setiap pasien bisa punya tanggal kunjungan yang berbeda dalam satu laporan', 'type': 'new'},
        {'icon': Icons.search_rounded, 'text': '🔍 Riwayat laporan bisa dicari & disaring dengan mudah, walau tanpa internet', 'type': 'new'},
        {'icon': Icons.auto_awesome_rounded, 'text': '✨ Nama pasien lama muncul otomatis saat diketik — menghemat waktu!', 'type': 'new'},
        {'icon': Icons.save_rounded, 'text': '💾 Laporan yang belum selesai tersimpan otomatis — tidak perlu takut hilang', 'type': 'new'},
        {'icon': Icons.description_rounded, 'text': '📄 Laporan PDF & Word lebih rapi — setiap pasien ada di halaman sendiri', 'type': 'improve'},
        {'icon': Icons.speed_rounded, 'text': '⚡ Aplikasi lebih ringan dan tidak lemot', 'type': 'improve'},
      ],
    },
    {
      'version': '2.2.0',
      'date': '11 Maret 2026',
      'changes': [
        {'icon': Icons.people_alt_rounded, 'text': '👥 Satu laporan sekarang bisa memuat banyak pasien sekaligus — tidak perlu laporan terpisah', 'type': 'new'},
        {'icon': Icons.drag_handle_rounded, 'text': '↕️ Urutan nama pasien bisa diubah dengan cara digeser', 'type': 'new'},
        {'icon': Icons.table_chart_rounded, 'text': '📋 Semua pasien otomatis masuk ke satu file PDF atau Word', 'type': 'improve'},
        {'icon': Icons.cloud_done_rounded, 'text': '🔄 Data lama diperbarui otomatis agar tetap bisa dibuka di versi baru', 'type': 'fix'},
      ],
    },
    {
      'version': '2.1.0',
      'date': '6 Maret 2026',
      'changes': [
        {'icon': Icons.add_circle_outline, 'text': '➕ Bisa tambahkan kolom pengukuran sendiri sesuai kebutuhan', 'type': 'new'},
        {'icon': Icons.description_outlined, 'text': '📝 File Word sekarang bisa dibuka normal di HP Android', 'type': 'fix'},
        {'icon': Icons.animation, 'text': '🚀 Tampilan awal aplikasi lebih cepat terbuka', 'type': 'improve'},
      ],
    },
    {
      'version': '2.0.0',
      'date': '28 Februari 2026',
      'changes': [
        {'icon': Icons.rocket_launch, 'text': '🎉 Tampilan aplikasi dibuat ulang — lebih cantik & nyaman dipakai!', 'type': 'new'},
        {'icon': Icons.picture_as_pdf, 'text': '📄 Laporan bisa dicetak ke file PDF atau Word langsung dari HP', 'type': 'new'},
        {'icon': Icons.mic, 'text': '🎤 Bisa isi data cukup dengan berbicara ke HP — tidak perlu ketik!', 'type': 'new'},
        {'icon': Icons.wifi_off, 'text': '📴 Tidak ada internet pun tetap bisa dipakai untuk catat kunjungan', 'type': 'new'},
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
