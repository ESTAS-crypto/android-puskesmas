import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'ui/ui.dart';

enum _DownloadStatus { idle, downloading, installing, error }

/// Dialog pembaruan aplikasi OTA.
/// Mengikuti spesifikasi Update.dc.html (Fase 7) dengan 3 tahap visual:
/// 1. Pembaruan tersedia
/// 2. Sedang mengunduh
/// 3. Perlu izin pemasangan / installer
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  _DownloadStatus _status = _DownloadStatus.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _errorMessage = '';
  File? _downloadedFile;

  // Hitungan mundur unduh otomatis (5 detik)
  int _autoCountdown = 5;
  Timer? _autoTimer;

  // Hitungan mundur install otomatis (3 detik)
  int _installCountdown = 3;
  Timer? _installTimer;

  // Estimasi kecepatan & sisa waktu
  int _lastBytes = 0;
  DateTime _lastTime = DateTime.now();
  double _speedBytesPerSec = 0.0;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();

    _startAutoCountdown();
  }

  void _startAutoCountdown() {
    _autoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_status != _DownloadStatus.idle) {
        timer.cancel();
        return;
      }
      if (_autoCountdown > 1) {
        setState(() => _autoCountdown--);
      } else {
        timer.cancel();
        _startDownload();
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _installTimer?.cancel();
    _animCtrl.dispose();
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
      return '${(_speedBytesPerSec / 1024).toStringAsFixed(0)} KB/dtk';
    }
    return '${(_speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/dtk';
  }

  String get _etaText {
    if (_speedBytesPerSec <= 0 ||
        _totalBytes <= 0 ||
        _receivedBytes >= _totalBytes) {
      return '';
    }
    final remainingBytes = _totalBytes - _receivedBytes;
    final seconds = (remainingBytes / _speedBytesPerSec).round();
    if (seconds <= 0) return '';
    if (seconds < 60) return '$seconds detik';
    return '${(seconds / 60).ceil()} menit';
  }

  Future<void> _startDownload() async {
    _autoTimer?.cancel();
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

      setState(() {
        _status = _DownloadStatus.installing;
        _downloadedFile = file;
        _installCountdown = 3;
      });

      // Hitungan mundur 3 detik sebelum otomatis memicu installer Android
      _installTimer =
          Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_installCountdown > 1) {
          setState(() => _installCountdown--);
        } else {
          timer.cancel();
          final success = await UpdateService.installApk(file);
          if (!mounted) return;
          if (!success) {
            setState(() {
              _status = _DownloadStatus.error;
              _errorMessage =
                  'Android meminta izin sekali saja. Buka pengaturan, aktifkan izin pasang dari aplikasi ini, lalu kembali ke sini.';
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _DownloadStatus.error;
          _errorMessage = 'Gagal mengunduh: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMandatory = widget.updateInfo.isMandatory;

    return PopScope(
      canPop: !isMandatory && _status != _DownloadStatus.downloading,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD3E4F1)),
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
              padding: const EdgeInsets.all(20),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: _buildStageContent(context, isMandatory),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent(BuildContext context, bool isMandatory) {
    switch (_status) {
      case _DownloadStatus.idle:
        return _buildStage1Available(context, isMandatory);
      case _DownloadStatus.downloading:
        return _buildStage2Downloading();
      case _DownloadStatus.installing:
        return _buildStage3Installing();
      case _DownloadStatus.error:
        return _buildStage3PermissionError(context, isMandatory);
    }
  }

  // ── TAHAP 1: PEMBARUAN TERSEDIA (Update.dc.html) ──
  Widget _buildStage1Available(BuildContext context, bool isMandatory) {
    final info = widget.updateInfo;
    final notes = info.releaseNotes.isNotEmpty
        ? info.releaseNotes.trim()
        : 'perbaikan & tampilan baru';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top row: Chip download icon + title & size
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(10, 100, 168, 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const AppIcon(
                AppGlyph.update,
                size: 24,
                color: AppTheme.primaryDeep,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Versi ${info.version} siap dipasang',
                    style: const TextStyle(
                      color: Color(0xFF0B2A40),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notes.contains('\n')
                        ? notes.split('\n').first.replaceAll('•', '').trim()
                        : notes,
                    style: const TextStyle(
                      color: Color(0xFF4A667E),
                      fontSize: 14,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),

        if (isMandatory) ...[
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: 'Pembaruan wajib',
              color: AppTheme.warning,
              icon: AppGlyph.warning,
            ),
          ),
        ],

        // Release notes box jika ada catatan detail
        if (notes.contains('\n')) ...[
          const SizedBox(height: 14),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD3E4F1)),
            ),
            child: SingleChildScrollView(
              child: Text(
                notes,
                style: const TextStyle(
                  color: Color(0xFF0B2A40),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Countdown auto download banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  value: _autoCountdown / 5.0,
                  strokeWidth: 2,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primaryDeep),
                  backgroundColor:
                      const Color.fromRGBO(10, 100, 168, 0.20),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Mengunduh otomatis dalam $_autoCountdown detik...',
                style: const TextStyle(
                  color: Color(0xFF3F5A70),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Primary Button: Unduh & pasang
        AppButton(
          label: 'Unduh & pasang',
          icon: AppGlyph.update,
          kind: AppButtonKind.primary,
          onPressed: () {
            _autoTimer?.cancel();
            _startDownload();
          },
        ),

        // Nanti saja jika tidak wajib
        if (!isMandatory) ...[
          const SizedBox(height: 10),
          Center(
            child: InkWell(
              onTap: () {
                _autoTimer?.cancel();
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'Nanti saja',
                  style: TextStyle(
                    color: Color(0xFF3F5A70),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── TAHAP 2: SEDANG MENGUNDUH (Update.dc.html) ──
  Widget _buildStage2Downloading() {
    final progressVal = _progress.clamp(0.0, 1.0);
    final pct = (progressVal * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mengunduh pembaruan…',
          style: TextStyle(
            color: Color(0xFF0B2A40),
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 16),

        // Bar (10px, radius 99, #EAF3FA, fill #0A64A8)
        Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FA),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progressVal,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryDeep,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Row: MB & percentage
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _totalBytes > 0
                  ? '${_formatBytes(_receivedBytes)} dari ${_formatBytes(_totalBytes)}'
                  : '${_formatBytes(_receivedBytes)} terunduh',
              style: const TextStyle(
                color: Color(0xFF3F5A70),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$pct%',
              style: const TextStyle(
                color: Color(0xFF0A64A8),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Subtext: ETA & Jangan tutup aplikasi
        Text(
          _etaText.isNotEmpty
              ? 'Sekitar $_etaText lagi. Jangan tutup aplikasi.'
              : (_speedText.isNotEmpty
                  ? 'Kecepatan $_speedText. Jangan tutup aplikasi.'
                  : 'Jangan tutup aplikasi.'),
          style: const TextStyle(
            color: Color(0xFF4A667E),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  // ── TAHAP 3A: MEMBUKA INSTALLER OTOMATIS ──
  Widget _buildStage3Installing() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(27, 127, 75, 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Siap dipasang',
                style: TextStyle(
                  color: Color(0xFF176B40),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Membuka installer Android…',
          style: TextStyle(
            color: Color(0xFF0B2A40),
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Peluncuran otomatis dalam $_installCountdown detik. Ketuk "Update / Pasang" pada layar Android.',
          style: const TextStyle(
            color: Color(0xFF3F5A70),
            fontSize: 15,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        if (_downloadedFile != null)
          AppButton(
            label: 'Buka installer sekarang',
            icon: AppGlyph.check,
            kind: AppButtonKind.primary,
            onPressed: () => UpdateService.installApk(_downloadedFile!),
          ),
      ],
    );
  }

  // ── TAHAP 3B: PERLU IZIN PEMASANGAN (Update.dc.html) ──
  Widget _buildStage3PermissionError(BuildContext context, bool isMandatory) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(176, 106, 0, 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Perlu izin',
                style: TextStyle(
                  color: Color(0xFF8A5200),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Izinkan pasang dari aplikasi ini',
          style: TextStyle(
            color: Color(0xFF0B2A40),
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Android meminta izin sekali saja. Buka pengaturan, aktifkan, lalu kembali ke sini.',
          style: TextStyle(
            color: Color(0xFF3F5A70),
            fontSize: 15,
            height: 1.45,
          ),
        ),
        if (_errorMessage.isNotEmpty &&
            !_errorMessage.contains('izin')) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD2D2)),
            ),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Primary: Buka izin di pengaturan HP
        AppButton(
          label: 'Buka izin di pengaturan HP',
          kind: AppButtonKind.primary,
          onPressed: () async {
            await UpdateService.openInstallPermissionSettings();
          },
        ),

        const SizedBox(height: 10),

        // Tonal: Coba lagi
        AppButton(
          label: 'Coba lagi',
          kind: AppButtonKind.tonal,
          onPressed: () async {
            if (_downloadedFile != null) {
              setState(() {
                _status = _DownloadStatus.installing;
                _installCountdown = 1;
              });
              final success =
                  await UpdateService.installApk(_downloadedFile!);
              if (!mounted) return;
              if (!success) {
                setState(() {
                  _status = _DownloadStatus.error;
                  _errorMessage =
                      'Izin belum aktif di pengaturan Android. Silakan ketuk tombol izin di atas.';
                });
              }
            } else {
              _startDownload();
            }
          },
        ),

        if (!isMandatory) ...[
          const SizedBox(height: 10),
          Center(
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'Tutup',
                  style: TextStyle(
                    color: Color(0xFF4A667E),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
