import 'dart:io';
import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

enum _DownloadStatus { idle, downloading, installing, error }

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> with TickerProviderStateMixin {
  _DownloadStatus _status = _DownloadStatus.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _errorMessage = '';
  File? _downloadedFile;

  // Kecepatan & estimasi waktu download
  int _lastBytes = 0;
  DateTime _lastTime = DateTime.now();
  double _speedBytesPerSec = 0.0;

  // Animasi Pop-up Dialog
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  // Animasi Shimmer (Cahaya Berjalan di Progress Bar)
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  // Animasi Pulse (Denyut Ikon Rocket & Glow)
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // 1. Animasi Masuk Dialog
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();

    // 2. Animasi Shimmer Efek Cahaya Bergerak
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    // 3. Animasi Denyut Halus Ikon & Efek Cahaya
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get _speedText {
    if (_speedBytesPerSec <= 0) return '';
    if (_speedBytesPerSec < 1024 * 1024) {
      return '⚡ ${(_speedBytesPerSec / 1024).toStringAsFixed(0)} KB/dtk';
    }
    return '⚡ ${(_speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/dtk';
  }

  String get _etaText {
    if (_speedBytesPerSec <= 0 || _totalBytes <= 0 || _receivedBytes >= _totalBytes) return '';
    final remainingBytes = _totalBytes - _receivedBytes;
    final seconds = (remainingBytes / _speedBytesPerSec).round();
    if (seconds <= 0) return '';
    if (seconds < 60) return '• $seconds dtk lagi';
    return '• ${(seconds / 60).ceil()} mnt lagi';
  }

  Future<void> _startDownload() async {
    setState(() {
      _status = _DownloadStatus.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = '';
      _lastBytes = 0;
      _lastTime = DateTime.now();
      _speedBytesPerSec = 0.0;
    });

    // Mulai animasi loop bergerak
    _shimmerCtrl.repeat();
    _pulseCtrl.repeat(reverse: true);

    try {
      final file = await UpdateService.downloadApk(
        widget.updateInfo.downloadUrl,
        widget.updateInfo.version,
        onProgress: (progress, received, total) {
          if (!mounted) return;

          final now = DateTime.now();
          final elapsedMs = now.difference(_lastTime).inMilliseconds;
          if (elapsedMs >= 350) {
            final bytesDiff = received - _lastBytes;
            _speedBytesPerSec = bytesDiff / (elapsedMs / 1000.0);
            _lastBytes = received;
            _lastTime = now;
          }

          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );

      if (!mounted) return;

      _shimmerCtrl.stop();
      _pulseCtrl.stop();

      setState(() {
        _status = _DownloadStatus.installing;
        _downloadedFile = file;
      });

      // Panggil package installer Android
      final success = await UpdateService.installApk(file);

      if (!mounted) return;

      if (!success) {
        setState(() {
          _status = _DownloadStatus.error;
          _errorMessage = 'Gagal membuka installer. Pastikan izin "Pasang aplikasi tidak dikenal" telah diizinkan di Pengaturan Android.';
        });
      }
    } catch (e) {
      if (mounted) {
        _shimmerCtrl.stop();
        _pulseCtrl.stop();
        setState(() {
          _status = _DownloadStatus.error;
          _errorMessage = 'Gagal mengunduh: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final isMandatory = info.isMandatory;

    return PopScope(
      canPop: !isMandatory && _status != _DownloadStatus.downloading,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.accentTeal.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentTeal.withValues(alpha: 0.18),
                    blurRadius: 32,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 25,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── HEADER IKON DENGAN ANIMASI PULSE ──
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) {
                        final isDownloading = _status == _DownloadStatus.downloading;
                        return Transform.scale(
                          scale: isDownloading ? _pulseAnim.value : 1.0,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentTeal.withValues(alpha: isDownloading ? 0.6 : 0.35),
                                  blurRadius: isDownloading ? 24 : 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              isDownloading
                                  ? Icons.cloud_download_rounded
                                  : (_status == _DownloadStatus.installing
                                      ? Icons.check_circle_rounded
                                      : Icons.rocket_launch_rounded),
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── TITLE ──
                  Center(
                    child: Text(
                      _status == _DownloadStatus.installing
                          ? 'Siap Dipasang!'
                          : (_status == _DownloadStatus.downloading
                              ? 'Mengunduh Pembaruan...'
                              : 'Pembaruan Tersedia!'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── BADGE VERSI DENGAN NEON GLOW ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'v${info.version} (Terbaru)',
                          style: const TextStyle(
                            color: AppTheme.accentTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Saat ini: v${UpdateService.currentVersion}',
                        style: const TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  if (isMandatory) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Pembaruan wajib untuk melanjutkan',
                              style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── BOX CATATAN PEMBARUAN (RELEASE NOTES) ──
                  if (_status != _DownloadStatus.downloading && _status != _DownloadStatus.installing) ...[
                    const Text(
                      'Apa yang baru:',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 130),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          info.releaseNotes.isNotEmpty
                              ? info.releaseNotes
                              : '• Peningkatan performa aplikasi\n• Perbaikan bug dan kestabilan sistem',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── ACTION AREA / INDIKATOR DOWNLOAD BERANIMASI ──
                  _buildActionArea(context, isMandatory),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionArea(BuildContext context, bool isMandatory) {
    switch (_status) {
      case _DownloadStatus.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _startDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Update Sekarang',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (!isMandatory) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Nanti Saja',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ],
        );

      // ── INDIKATOR DOWNLOAD SUPER SMOOTH & SHIMMER BERANIMASI ──
      case _DownloadStatus.downloading:
        final progressVal = (_progress.clamp(0.0, 1.0));
        final pct = (_progress >= 0 ? (progressVal * 100).toInt() : 0);

        return Column(
          children: [
            // Status Header & Persentase Halus
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _speedText.isNotEmpty ? 'Mengunduh ($_speedText)' : 'Mengunduh pembaruan...',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: AppTheme.accentTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── PROGRESS BAR SUPER SMOOTH DENGAN TWEEN & SHIMMER WAVE ──
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progressVal),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, animatedProgress, _) {
                return Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider, width: 1),
                  ),
                  child: Stack(
                    children: [
                      // 1. Bar Terisi (Gradient Cyan-Teal)
                      FractionallySizedBox(
                        widthFactor: animatedProgress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BFA6), Color(0xFF448AFF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00BFA6).withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 2. Animasi Shimmer Bergerak (Efek Kilatan Cahaya)
                      if (animatedProgress > 0.03)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _shimmerAnim,
                            builder: (context, _) {
                              return FractionallySizedBox(
                                widthFactor: animatedProgress,
                                alignment: Alignment.centerLeft,
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      begin: Alignment(_shimmerAnim.value - 1.2, 0),
                                      end: Alignment(_shimmerAnim.value, 0),
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.45),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcATop,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(9),
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Informasi Ukuran & Estimasi Waktu Sisa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatBytes(_receivedBytes),
                  style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                ),
                Text(
                  _totalBytes > 0
                      ? '${_formatBytes(_totalBytes)} $_etaText'
                      : 'Menghitung ukuran...',
                  style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Aplikasi akan otomatis membuka installer setelah selesai',
              style: TextStyle(color: AppTheme.textHint, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        );

      case _DownloadStatus.installing:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Membuka Installer Android...',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ketuk tombol "Update / Pasang" pada layar Android Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (_downloadedFile != null)
              OutlinedButton.icon(
                onPressed: () => UpdateService.installApk(_downloadedFile!),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Buka Ulang Installer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentTeal,
                  side: const BorderSide(color: AppTheme.accentTeal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        );

      case _DownloadStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: AppTheme.error, fontSize: 11.5, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _startDownload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (!isMandatory) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup', style: TextStyle(color: AppTheme.textHint)),
              ),
            ],
          ],
        );
    }
  }
}
