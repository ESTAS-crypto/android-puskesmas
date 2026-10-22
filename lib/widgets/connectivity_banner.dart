import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'ui/ui.dart';

enum _BannerKind { off, sync, done, fail }

/// Widget yang menampilkan banner koneksi interaktif sesuai spesifikasi
/// "Laut & Langit" (Main.dc.html & status-prototype.html).
///
/// 4 status:
/// - offline (amber lembut)
/// - sinkronisasi (biru + progress bar)
/// - selesai (hijau + auto-hide 4 detik)
/// - gagal (amber + tombol Coba lagi)
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  bool _showBanner = false;
  bool _isFirstCheck = true;
  int _pendingCount = 0;
  String _customSubtitle = '';
  _BannerKind _kind = _BannerKind.off;

  Timer? _checkTimer;
  Timer? _autoHideTimer;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
      reverseDuration: AppMotion.fast,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: AppMotion.decelerate,
      reverseCurve: AppMotion.accelerate,
    ));

    _checkConnectivity();
    // Pengecekan koneksi berkala setiap 5 detik
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnectivity());
  }

  void _show() {
    _autoHideTimer?.cancel();
    if (!_showBanner) {
      setState(() => _showBanner = true);
    }
    _animCtrl.forward();
  }

  void _hide() {
    _autoHideTimer?.cancel();
    _animCtrl.reverse().then((_) {
      if (mounted) {
        setState(() => _showBanner = false);
      }
    });
  }

  Future<void> _checkConnectivity() async {
    bool online;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    if (!mounted) return;

    if (online != _isOnline) {
      final pending = await StorageService.getPendingSyncCount();
      _isOnline = online;

      if (!online) {
        // Sinyal hilang -> Mode offline
        setState(() {
          _kind = _BannerKind.off;
          _pendingCount = pending;
          _customSubtitle = '';
        });
        _show();
      } else {
        // Sinyal kembali -> Mulai sinkronisasi
        _pendingCount = pending;
        if (pending > 0) {
          setState(() {
            _kind = _BannerKind.sync;
            _customSubtitle = 'Menyinkronkan $pending laporan…';
          });
          _show();
          await _triggerAutoSync();
        } else {
          setState(() {
            _kind = _BannerKind.done;
            _customSubtitle = 'Semua data sudah sinkron';
          });
          _show();
          _scheduleAutoHide();
        }
      }
    }

    // Pemeriksaan awal saat aplikasi pertama kali terbuka
    if (_isFirstCheck) {
      _isFirstCheck = false;
      if (!online) {
        final pending = await StorageService.getPendingSyncCount();
        setState(() {
          _kind = _BannerKind.off;
          _pendingCount = pending;
        });
        _show();
      }
    }
  }

  Future<void> _triggerAutoSync({bool isRetry = false}) async {
    try {
      if (isRetry) {
        final pending = await StorageService.getPendingSyncCount();
        setState(() {
          _kind = _BannerKind.sync;
          _pendingCount = pending;
          _customSubtitle = 'Menyinkronkan $pending laporan…';
        });
        _show();
      }

      if (!SupabaseService.isLoggedIn) {
        if (mounted) {
          setState(() {
            _kind = _BannerKind.done;
            _customSubtitle = 'Data tersimpan lokal di HP';
          });
          _scheduleAutoHide();
        }
        return;
      }

      final synced = await StorageService.syncPendingReports();
      if (!mounted) return;

      setState(() {
        _kind = _BannerKind.done;
        _pendingCount = 0;
        _customSubtitle = synced > 0
            ? '$synced laporan berhasil disinkronkan'
            : 'Semua data sudah sinkron';
      });
      _scheduleAutoHide();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _kind = _BannerKind.fail;
        _customSubtitle = 'Akan dicoba lagi otomatis.';
      });
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isOnline && _kind == _BannerKind.done) {
        _hide();
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _autoHideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: RepaintBoundary(
              child: SlideTransition(
                position: _slideAnim,
                child: Semantics(
                  liveRegion: true,
                  child: _buildBannerCard(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerCard() {
    final (tileBg, glyph, iconColor, title, defaultSubtitle) = switch (_kind) {
      _BannerKind.off => (
          const Color.fromRGBO(176, 106, 0, 0.14),
          AppGlyph.wifiOff,
          AppTheme.warning,
          'Mode offline',
          'Data tersimpan di HP. Terkirim otomatis saat ada sinyal.',
        ),
      _BannerKind.sync => (
          const Color.fromRGBO(10, 100, 168, 0.12),
          AppGlyph.wifi,
          AppTheme.accent,
          'Kembali online',
          _pendingCount > 0
              ? 'Menyinkronkan $_pendingCount laporan…'
              : 'Menyinkronkan data…',
        ),
      _BannerKind.done => (
          const Color.fromRGBO(27, 127, 75, 0.12),
          AppGlyph.check,
          AppTheme.success,
          'Semua data sudah terkirim',
          _customSubtitle.isNotEmpty
              ? _customSubtitle
              : 'Data berhasil disinkronkan',
        ),
      _BannerKind.fail => (
          const Color.fromRGBO(176, 106, 0, 0.14),
          AppGlyph.warning,
          AppTheme.warning,
          'Belum berhasil mengirim',
          'Akan dicoba lagi otomatis.',
        ),
    };

    final subtitle = _customSubtitle.isNotEmpty ? _customSubtitle : defaultSubtitle;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outline),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(11, 42, 64, 0.14),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Tile ikon status
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppIcon(glyph, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                // Judul & sub-judul
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textFaint,
                          fontSize: 13,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Trailing: Pill laporan pending atau Tombol Coba lagi
                if (_kind == _BannerKind.off && _pendingCount > 0) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    label: '$_pendingCount belum terkirim',
                    color: AppTheme.warning,
                  ),
                ] else if (_kind == _BannerKind.fail) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => _triggerAutoSync(isRetry: true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ],
            ),
            // Bar progres saat sinkronisasi
            if (_kind == _BannerKind.sync) ...[
              const SizedBox(height: 10),
              Container(
                height: 6,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
