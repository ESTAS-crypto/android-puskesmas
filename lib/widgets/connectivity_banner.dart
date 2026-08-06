import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

/// Widget yang menampilkan banner/popup animasi ketika status koneksi berubah.
/// Otomatis muncul di atas layar saat offline dan saat kembali online.
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
  int _pendingCount = 0; // ponytail: track pending sync count
  String _syncMessage = ''; // ponytail: dynamic subtitle
  Timer? _timer;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _checkConnectivity();
    // Cek koneksi setiap 5 detik
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnectivity());
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
      // ponytail: update pending count on transition
      final pending = await StorageService.getPendingSyncCount();
      setState(() {
        _isOnline = online;
        _showBanner = true;
        _pendingCount = pending;
        _syncMessage = '';
      });
      _animCtrl.forward();

      // Saat kembali online: sync pending reports
      if (online) {
        _triggerAutoSync();
        // Auto-hide banner setelah 4 detik (sedikit lebih lama untuk feedback)
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _isOnline) {
            _animCtrl.reverse().then((_) {
              if (mounted) setState(() => _showBanner = false);
            });
          }
        });
      }
    }

    // Pertama kali cek, jangan tampilkan banner kecuali offline
    if (_isFirstCheck) {
      _isFirstCheck = false;
      if (!online) {
        final pending = await StorageService.getPendingSyncCount();
        setState(() {
          _showBanner = true;
          _pendingCount = pending;
        });
        _animCtrl.forward();
      }
    }
  }

  /// ponytail: Sync hanya report yang pending, tampilkan hasil
  Future<void> _triggerAutoSync() async {
    try {
      if (!SupabaseService.isLoggedIn) return;
      final synced = await StorageService.syncPendingReports();
      if (mounted && synced > 0) {
        setState(() => _syncMessage = '$synced laporan berhasil disinkronkan');
      } else if (mounted) {
        setState(() => _syncMessage = 'Semua data sudah sinkron');
      }
    } catch (_) {
      if (mounted) setState(() => _syncMessage = 'Gagal sinkronisasi, akan dicoba lagi');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? const Color(0xFF1B5E20).withValues(alpha: 0.95)
                        : const Color(0xFFB71C1C).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (_isOnline ? Colors.green : Colors.red).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isOnline ? 'Kembali Online' : 'Mode Offline',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              // ponytail: dynamic subtitle with pending count / sync result
                              _isOnline
                                  ? (_syncMessage.isNotEmpty ? _syncMessage : 'Menyinkronkan data...')
                                  : _pendingCount > 0
                                      ? '$_pendingCount laporan menunggu sinkronisasi'
                                      : 'Data tersimpan di lokal, akan sync saat online',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isOnline ? Colors.greenAccent : Colors.redAccent)
                                  .withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
