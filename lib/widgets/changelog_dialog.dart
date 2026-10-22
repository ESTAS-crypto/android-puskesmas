import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/ui.dart';

/// Modal bottom sheet "Apa yang baru" sesuai spesifikasi Changelog.dc.html.
class ChangelogDialog {
  static const String _currentVersion = '2.7.5';
  static const String _seenVersionKey = 'changelog_seen_version';

  static final List<Map<String, dynamic>> _changelog = [
    {
      'version': '2.7.5',
      'date': '17 Juli 2026',
      'changes': [
        {
          'type': 'new',
          'label': 'Baru',
          'text': 'Admin bisa ubah data pasien langsung dari halaman Admin. Tinggal ketuk tombol edit.',
        },
        {
          'type': 'new',
          'label': 'Baru',
          'text': 'Ada pemberitahuan berapa laporan yang belum terkirim dan yang berhasil terkirim.',
        },
        {
          'type': 'improve',
          'label': 'Peningkatan',
          'text': 'Saat HP kembali online, laporan otomatis terkirim ke server. Tidak perlu kirim ulang.',
        },
        {
          'type': 'fix',
          'label': 'Perbaikan',
          'text': 'Foto pasien kini ikut muncul saat cetak laporan dari halaman Admin.',
        },
      ],
    },
    {
      'version': '2.7.0',
      'date': '19 Mei 2026',
      'changes': [
        {
          'type': 'new',
          'label': 'Baru',
          'text': 'Sistem role baru: Owner › Developer › Admin › User dengan batas wewenang bertingkat.',
        },
        {
          'type': 'new',
          'label': 'Baru',
          'text': 'Admin tidak bisa mengubah role — hanya Developer dan Owner yang memiliki akses pengelolaan role.',
        },
        {
          'type': 'fix',
          'label': 'Perbaikan',
          'text': 'Role otomatis diperbarui saat aplikasi dibuka tanpa perlu logout.',
        },
      ],
    },
    {
      'version': '2.6.0',
      'date': '20 April 2026',
      'changes': [
        {
          'type': 'new',
          'label': 'Baru',
          'text': 'Dukungan masuk menggunakan akun Google (Gmail) sekali ketuk.',
        },
        {
          'type': 'new',
          'label': 'Baru',
          'text': 'Pembersihan otomatis berkas lokal dan cloud yang telah melewati masa simpan.',
        },
        {
          'type': 'improve',
          'label': 'Peningkatan',
          'text': 'Optimalisasi waktu muat aplikasi dan efisiensi konsumsi memori.',
        },
      ],
    },
  ];

  /// Cek apakah changelog perlu ditampilkan otomatis (versi baru terdeteksi)
  static Future<bool> shouldShowChangelog() async {
    final prefs = await SharedPreferences.getInstance();
    final seenVersion = prefs.getString(_seenVersionKey);
    return seenVersion != _currentVersion;
  }

  /// Tandai versi saat ini sudah dilihat
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenVersionKey, _currentVersion);
  }

  /// Tampilkan bottom sheet Changelog (Changelog.dc.html)
  static Future<void> show(BuildContext context, {bool isAutoShow = false}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ChangelogBottomSheet(),
    );

    if (isAutoShow) {
      await markAsSeen();
    }
  }
}

class _ChangelogBottomSheet extends StatefulWidget {
  const _ChangelogBottomSheet();

  @override
  State<_ChangelogBottomSheet> createState() => _ChangelogBottomSheetState();
}

class _ChangelogBottomSheetState extends State<_ChangelogBottomSheet> {
  final Set<String> _expandedVersions = {};

  @override
  Widget build(BuildContext context) {
    final latest = ChangelogDialog._changelog.first;
    final older = ChangelogDialog._changelog.skip(1).toList();
    final latestChanges = latest['changes'] as List<Map<String, dynamic>>;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(11, 42, 64, 0.16),
            blurRadius: 34,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD3E4F1),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),

          // Header: Title + Pill
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Apa yang baru',
                  style: TextStyle(
                    color: Color(0xFF0B2A40),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(27, 127, 75, 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Versi terbaru',
                  style: TextStyle(
                    color: Color(0xFF176B40),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Version & date subtitle
          Text(
            'v${latest['version']} · ${latest['date']}',
            style: const TextStyle(
              color: Color(0xFF3F5A70),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          // Scrollable list of changes
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Latest version items (Changelog.dc.html lines 36-39)
                  for (final item in latestChanges) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTypePill(item['type'] as String, item['label'] as String),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['text'] as String,
                              style: const TextStyle(
                                color: Color(0xFF0B2A40),
                                fontSize: 15.5,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Divider before older versions
                  if (older.isNotEmpty) ...[
                    const Divider(color: Color(0xFFD3E4F1), height: 28),
                    for (final ver in older) ...[
                      _buildOlderVersionTile(ver),
                    ],
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Mengerti button
          AppButton(
            label: 'Mengerti',
            kind: AppButtonKind.primary,
            onPressed: () async {
              await ChangelogDialog.markAsSeen();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill(String type, String label) {
    Color bg;
    Color fg;

    switch (type) {
      case 'new':
        bg = const Color.fromRGBO(10, 100, 168, 0.10);
        fg = const Color(0xFF0A64A8);
        break;
      case 'improve':
        bg = const Color.fromRGBO(176, 106, 0, 0.14);
        fg = const Color(0xFF8A5200);
        break;
      case 'fix':
      default:
        bg = const Color.fromRGBO(27, 127, 75, 0.12);
        fg = const Color(0xFF176B40);
        break;
    }

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOlderVersionTile(Map<String, dynamic> ver) {
    final v = ver['version'] as String;
    final date = ver['date'] as String;
    final changes = ver['changes'] as List<Map<String, dynamic>>;
    final isExpanded = _expandedVersions.contains(v);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedVersions.remove(v);
              } else {
                _expandedVersions.add(v);
              }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'v$v',
                        style: const TextStyle(
                          color: Color(0xFF0B2A40),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$date · ${changes.length} perubahan',
                        style: const TextStyle(
                          color: Color(0xFF4A667E),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF3F5A70),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              children: [
                for (final item in changes) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTypePill(
                            item['type'] as String, item['label'] as String),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['text'] as String,
                            style: const TextStyle(
                              color: Color(0xFF0B2A40),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
