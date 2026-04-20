import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../models/resident_exam.dart';

/// Service wrapper untuk semua interaksi dengan Supabase cloud database.
/// Strategi: Offline-First — semua operasi cloud bersifat fire-and-forget.
class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Ukuran maksimum file foto: 10 MB
  static const int _maxFileSize = 10 * 1024 * 1024;

  /// Terjemahkan pesan error Supabase dari Inggris ke Bahasa Indonesia.
  static String _translateError(String msg) {
    final lower = msg.toLowerCase();
    // Auth errors
    if (lower.contains('invalid login credentials')) return 'Email/username atau password salah.';
    if (lower.contains('email not confirmed')) return 'Email belum dikonfirmasi. Cek inbox untuk kode OTP.';
    if (lower.contains('user already registered')) return 'Email sudah terdaftar. Silakan login.';
    if (lower.contains('signup requires a valid password')) return 'Password tidak valid. Minimal 6 karakter.';
    if (lower.contains('password should be at least')) return 'Password terlalu pendek. Minimal 6 karakter.';
    if (lower.contains('new password should be different')) return 'Password baru tidak boleh sama dengan password lama.';
    if (lower.contains('same password')) return 'Password baru tidak boleh sama dengan password lama.';
    if (lower.contains('unable to validate email')) return 'Format email tidak valid.';
    if (lower.contains('invalid email')) return 'Format email tidak valid.';
    if (lower.contains('rate limit') || lower.contains('too many requests')) return 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.';
    if (lower.contains('email rate limit exceeded')) return 'Batas pengiriman email tercapai. Tunggu 1 jam lalu coba lagi.';
    if (lower.contains('otp expired') || lower.contains('token has expired')) return 'Kode OTP sudah kedaluwarsa. Minta kode baru.';
    if (lower.contains('invalid otp') || lower.contains('token is invalid')) return 'Kode OTP tidak valid. Periksa kembali kode dari email.';
    if (lower.contains('user not found')) return 'Akun tidak ditemukan.';
    if (lower.contains('email not found')) return 'Email tidak terdaftar.';
    if (lower.contains('phone') && lower.contains('already')) return 'Nomor telepon sudah terdaftar.';
    if (lower.contains('network') || lower.contains('socket') || lower.contains('connection')) return 'Tidak ada koneksi internet. Periksa jaringan Anda.';
    if (lower.contains('timeout')) return 'Koneksi timeout. Coba lagi.';
    // Admin/RLS errors
    if (lower.contains('not authorized') || lower.contains('not allowed')) return 'Tidak diizinkan. Pastikan Anda memiliki akses admin.';
    if (lower.contains('permission denied') || lower.contains('rls')) return 'Akses ditolak oleh kebijakan keamanan server (RLS). Hubungi developer.';
    if (lower.contains('row-level security') || lower.contains('policy')) return 'Akses ditolak oleh kebijakan keamanan (RLS). Buat policy di Supabase.';
    if (lower.contains('violates foreign key')) return 'Data tidak bisa dihapus karena masih terhubung ke data lain.';
    if (lower.contains('violates not-null')) return 'Data wajib tidak boleh kosong.';
    if (lower.contains('jwt') || lower.contains('unauthorized')) return 'Sesi login sudah kedaluwarsa. Silakan login ulang.';
    if (lower.contains('service_role') || lower.contains('service role')) return 'Fitur ini membutuhkan konfigurasi khusus di server (service_role key).';
    if (lower.contains('storage') && lower.contains('not found')) return 'File/bucket tidak ditemukan di storage.';
    if (lower.contains('bucket') && lower.contains('not found')) return 'Bucket storage tidak ditemukan. Buat bucket "photos" di Supabase.';
    if (lower.contains('object not found')) return 'File tidak ditemukan di storage.';
    if (lower.contains('the resource was not found') || lower.contains('404')) return 'Data tidak ditemukan di server.';
    // Fallback: kembalikan pesan asli
    return msg;
  }

  // ─────────────────────────────────────────────
  // AUTHENTICATION
  // ─────────────────────────────────────────────

  /// User ID dari sesi login Supabase yang sedang aktif.
  static String? get currentUserId => _client.auth.currentUser?.id;

  /// Cek apakah user sedang login.
  static bool get isLoggedIn => _client.auth.currentUser != null;

  /// Register akun baru dengan email + password.
  /// Hanya membuat akun, BELUM simpan profil (tunggu verifikasi OTP dulu).
  static Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Cek apakah username sudah dipakai
      final existing = await _client
          .from('profiles')
          .select('username')
          .eq('username', username.toLowerCase())
          .maybeSingle();
      if (existing != null) {
        return 'Username "$username" sudah dipakai. Pilih username lain.';
      }

      final res = await _client.auth.signUp(email: email, password: password);
      if (res.user == null) {
        return 'Registrasi gagal. Silakan coba lagi.';
      }

      return null; // Sukses — tunggu OTP
    } on AuthException catch (e) {
      return _translateError(e.message);
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Verifikasi OTP signup (konfirmasi email setelah register).
  /// Setelah berhasil, simpan profil ke tabel profiles.
  static Future<String?> verifySignupOtp({
    required String email,
    required String otp,
    required String username,
    String nama = '',
    String puskesmas = '',
  }) async {
    try {
      final res = await _client.auth.verifyOTP(
        type: OtpType.signup,
        token: otp,
        email: email,
      );
      if (res.session == null) return 'Kode OTP tidak valid atau sudah kedaluwarsa.';

      // OTP valid → user otomatis login → simpan profil
      final userId = res.user?.id;
      if (userId != null) {
        await _client.from('profiles').upsert({
          'id': userId,
          'username': username.toLowerCase(),
          'email': email.toLowerCase(),
          'nama': nama,
          'puskesmas': puskesmas,
        });
      }

      return null; // Sukses
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Login dengan email ATAU username + password.
  /// Otomatis deteksi: jika ada '@' → email, jika tidak → username.
  static Future<String?> signIn(String emailOrUsername, String password) async {
    try {
      String email = emailOrUsername.trim();

      // Jika bukan email → cari email dari tabel profiles
      if (!email.contains('@')) {
        final profile = await _client
            .from('profiles')
            .select('email')
            .eq('username', email.toLowerCase())
            .maybeSingle();
        if (profile == null) {
          return 'Username "$email" tidak ditemukan.';
        }
        email = profile['email'] as String;
      }

      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) {
        return 'Login gagal. Periksa username/email dan password Anda.';
      }
      return null; // Sukses
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Kirim email reset password.
  static Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Verifikasi kode OTP 8-angka yang dikirim ke email
  static Future<String?> verifyResetOtp(String email, String otp) async {
    try {
      final res = await _client.auth.verifyOTP(
        type: OtpType.recovery,
        token: otp,
        email: email,
      );
      if (res.session == null) return 'Kode OTP tidak valid atau sudah kedaluwarsa.';
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Update password baru setelah OTP terverifikasi (dan user otomatis login)
  static Future<String?> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Logout dari Supabase.
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseService] signOut error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // GOOGLE SIGN-IN
  // ─────────────────────────────────────────────

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '824087521061-oh6sheu9lp08tf1onni7op38fj6f8ja03.apps.googleusercontent.com', 
  );

  /// Sign in menggunakan akun Google.
  /// Mengembalikan [Map] dengan kunci:
  ///   - 'error': String? (null jika sukses)
  ///   - 'isNewUser': bool (true jika pengguna belum pernah mendaftar)
  ///   - 'email': String
  ///   - 'googleName': String (nama dari akun Google)
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'error': 'Login dibatalkan oleh pengguna.'};
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return {'error': 'Gagal mendapatkan token Google. Coba lagi.'};
      }

      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (res.user == null) {
        return {'error': 'Login Google gagal. Silakan coba lagi.'};
      }

      final userId = res.user!.id;

      // Cek apakah sudah ada profil di table profiles
      final existingProfile = await _client
          .from('profiles')
          .select('nama, puskesmas')
          .eq('id', userId)
          .maybeSingle();

      final bool isNewUser = existingProfile == null ||
          (existingProfile['nama'] as String? ?? '').isEmpty;

      return {
        'error': null,
        'isNewUser': isNewUser,
        'email': googleUser.email,
        'googleName': googleUser.displayName ?? '',
        'existingNama': existingProfile?['nama'] as String? ?? '',
        'existingPuskesmas': existingProfile?['puskesmas'] as String? ?? '',
      };
    } on AuthException catch (e) {
      return {'error': _translateError(e.message)};
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('sign_in_failed') || msg.contains('network_error')) {
        return {'error': 'Koneksi gagal. Pastikan internet aktif dan coba lagi.'};
      }
      if (msg.contains('sign_in_canceled') || msg.contains('canceled')) {
        return {'error': 'Login dibatalkan.'};
      }
      return {'error': 'Login Google gagal: $e'};
    }
  }

  /// Simpan profil pertama kali setelah Google Sign-In.
  static Future<String?> saveGoogleProfile({
    required String nama,
    required String puskesmas,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return 'Sesi tidak ditemukan. Coba login ulang.';
      final email = _client.auth.currentUser?.email ?? '';

      await _client.from('profiles').upsert({
        'id': userId,
        'email': email,
        'nama': nama,
        'puskesmas': puskesmas,
        'username': email.split('@').first.toLowerCase(),
      });
      return null;
    } catch (e) {
      return 'Gagal menyimpan profil: $e';
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN AUTO-CLEAN SERVER DATA
  // ─────────────────────────────────────────────

  /// Hapus otomatis laporan & foto dari server berdasarkan pengaturan admin.
  /// Dipanggil saat Admin membuka Dashboard (non-blocking / fire-and-forget).
  static Future<void> adminAutoCleanServerData({
    required int photoDeleteDays,
    required int reportDeleteDays,
  }) async {
    if (!isLoggedIn) return;
    try {
      final now = DateTime.now();

      // 1. Hapus foto lama dari Storage berdasarkan tanggal modifikasi
      if (photoDeleteDays > 0) {
        final cutoffDate = now.subtract(Duration(days: photoDeleteDays));
        final allPhotos = await _client.storage.from('photos').list();
        int deletedPhotos = 0;
        for (final photo in allPhotos) {
          final updatedAt = photo.updatedAt;
          if (updatedAt != null) {
            final photoDate = DateTime.tryParse(updatedAt);
            if (photoDate != null && photoDate.isBefore(cutoffDate)) {
              try {
                await _client.storage.from('photos').remove([photo.name]);
                deletedPhotos++;
              } catch (_) {}
            }
          }
        }
        if (deletedPhotos > 0) {
          debugPrint('[AdminAutoClean] Foto dihapus dari storage: $deletedPhotos');
        }
      }

      // 2. Hapus exam lama dari database berdasarkan kolom tanggal
      if (reportDeleteDays > 0) {
        final cutoffDate = now.subtract(Duration(days: reportDeleteDays));
        final cutoffStr = cutoffDate.toIso8601String().substring(0, 10);

        // Hapus exams yang tanggal_kunjungannya sebelum batas
        final deleted = await _client
            .from('resident_exams')
            .delete()
            .lt('created_at', cutoffStr)
            .select('id');

        debugPrint('[AdminAutoClean] Exam rows dihapus: ${deleted.length}');

        // Hapus reports yang sudah tidak memiliki exam (orphan reports)
        // Dilakukan dengan subquery: hapus reports yang tidak ada di resident_exams
        await _client.rpc('delete_orphan_reports');
      }
    } catch (e) {
      debugPrint('[AdminAutoClean] Error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // UPLOAD / UPSERT
  // ─────────────────────────────────────────────

  /// Sync satu Report beserta semua ResidentExam-nya ke Supabase.
  static Future<void> syncReportToCloud(Report report) async {
    try {
      final userId = currentUserId;
      if (userId == null) return; // Belum login, skip sync

      // Ambil profil user untuk disimpan di report (agar global search bisa tampilkan pemilik)
      String userNama = '';
      String userPuskesmas = '';
      try {
        final profile = await _client
            .from('profiles')
            .select('nama, puskesmas')
            .eq('id', userId)
            .maybeSingle();
        if (profile != null) {
          userNama = profile['nama'] as String? ?? '';
          userPuskesmas = profile['puskesmas'] as String? ?? '';
        }
      } catch (_) {}

      // Upsert report dengan user_id + info pemilik
      await _client.from('reports').upsert({
        'id': report.id,
        'no': report.no,
        'created_at': report.createdAt.toIso8601String(),
        'user_id': userId,
        'user_nama': userNama,
        'user_puskesmas': userPuskesmas,
      });

      // Upsert semua exam yang terkait
      for (final exam in report.exams) {
        try {
          // Upload foto ke cloud jika path-nya lokal (bukan URL cloud)
          String? cloudFotoUrl = exam.fotoPath;
          if (exam.fotoPath != null &&
              !exam.fotoPath!.startsWith('http') &&
              File(exam.fotoPath!).existsSync()) {
            cloudFotoUrl = await uploadPhoto(exam.fotoPath!, exam.id);
          }

          final row = _examToRow(exam, report.id);
          row['foto_path'] = cloudFotoUrl;

          try {
            await _client.from('resident_exams').upsert(row);
          } catch (e) {
            // Jika gagal kemungkinan karena kolom tanggal_lahir belum ada di DB
            // Coba lagi tanpa kolom itu sebagai fallback
            debugPrint('[SupabaseService] upsert exam failed (mungkin kolom tanggal_lahir belum ada): $e');
            final rowFallback = Map<String, dynamic>.from(row)..remove('tanggal_lahir');
            await _client.from('resident_exams').upsert(rowFallback);
            debugPrint('[SupabaseService] upsert exam fallback SUCCESS untuk ${exam.nama}');
          }
        } catch (e) {
          debugPrint('[SupabaseService] gagal upsert exam ${exam.nama}: $e');
          // Lanjut ke exam berikutnya meski satu gagal
        }
      }
    } catch (e) {
      debugPrint('[SupabaseService] syncReportToCloud error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // PHOTO UPLOAD
  // ─────────────────────────────────────────────

  /// Upload foto ke Supabase Storage bucket 'photos'.
  /// Menggunakan nama file berbasis examId agar tidak duplikat.
  static Future<String?> uploadPhoto(String localPath, String examId) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        debugPrint('[SupabaseService] File terlalu besar: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB (max 10 MB)');
        return null;
      }

      final ext = localPath.split('.').last;
      // Gunakan examId sebagai nama file agar idempoten (tidak ada duplikat)
      final fileName = 'exam_$examId.$ext';

      await _client.storage.from('photos').upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = _client.storage.from('photos').getPublicUrl(fileName);
      debugPrint('[SupabaseService] Foto berhasil diupload: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[SupabaseService] uploadPhoto error: $e');
      return null;
    }
  }

  /// Generate public URL foto langsung dari examId (tanpa perlu list photos).
  /// Format nama file: exam_{examId}.{ext}
  static String? getPhotoPublicUrl(String examId) {
    if (examId.isEmpty) return null;
    // Coba ekstensi umum — Supabase Storage selalu return URL walau file tidak ada
    for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
      try {
        final url = _client.storage.from('photos').getPublicUrl('exam_$examId.$ext');
        if (url.isNotEmpty) return url;
      } catch (_) {}
    }
    return null;
  }

  /// Sync semua reports dari data lokal ke Supabase sekaligus.
  static Future<void> syncAllToCloud(List<Report> reports) async {
    try {
      for (final report in reports) {
        await syncReportToCloud(report);
      }
    } catch (e) {
      debugPrint('[SupabaseService] syncAllToCloud error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // REMOTE CONFIG (Auto-Delete Lokal)
  // ─────────────────────────────────────────────

  /// Simpan konfigurasi auto-delete lokal ke Supabase (admin only).
  static Future<String?> saveLocalDeleteConfig(int value, String unit) async {
    try {
      await _client.from('app_config').upsert({
        'key': 'local_auto_delete',
        'value': {'delete_value': value, 'delete_unit': unit},
      });
      return null;
    } catch (e) {
      debugPrint('[SupabaseService] saveLocalDeleteConfig error: $e');
      return _translateError(e.toString());
    }
  }

  /// Ambil konfigurasi auto-delete lokal dari Supabase, simpan ke cache lokal.
  /// Return: jumlah hari yang harus dihapus (0 = nonaktif).
  static Future<int> fetchAndCacheLocalDeleteConfig() async {
    try {
      final result = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'local_auto_delete')
          .maybeSingle();
      if (result != null && result['value'] != null) {
        final config = result['value'] as Map<String, dynamic>;
        final val = config['delete_value'] as int? ?? 0;
        final unit = config['delete_unit'] as String? ?? 'hari';
        int days = val;
        if (unit == 'minggu') days = val * 7;
        if (unit == 'bulan') days = val * 30;
        // Cache ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('local_ad_days', days);
        await prefs.setInt('local_ad_val', val);
        await prefs.setString('local_ad_unit', unit);
        debugPrint('[SupabaseService] Remote config fetched: $val $unit ($days days)');
        return days;
      }
      return 0;
    } catch (e) {
      debugPrint('[SupabaseService] fetchLocalDeleteConfig error: $e');
      // Fallback ke cache lokal
      try {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getInt('local_ad_days') ?? 0;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Ambil config lokal dari cache (tanpa koneksi internet).
  static Future<int> getCachedLocalDeleteDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('local_ad_days') ?? 0;
  }

  // ─────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────

  /// Hapus satu Report (dan exam terkait via CASCADE) dari Supabase.
  static Future<void> deleteReportFromCloud(String reportId) async {
    try {
      await _client.from('reports').delete().eq('id', reportId);
    } catch (e) {
      debugPrint('[SupabaseService] deleteReportFromCloud error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // FETCH / DOWNLOAD (untuk login di device baru)
  // ─────────────────────────────────────────────

  /// Ambil semua data Reports milik user ini dari cloud.
  /// Dipakai saat login di device baru untuk restore data.
  static Future<List<Report>> downloadFromCloud() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final reportsData = await _client
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('no', ascending: true);

      final List<Report> results = [];

      for (final r in reportsData) {
        final examsData = await _client
            .from('resident_exams')
            .select()
            .eq('report_id', r['id'] as String);

        final exams = examsData
            .map((e) => _rowToExam(e))
            .toList();

        results.add(Report(
          id: r['id'] as String,
          no: r['no'] as int,
          createdAt: DateTime.parse(r['created_at'] as String),
          exams: exams,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('[SupabaseService] downloadFromCloud error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  static Map<String, dynamic> _examToRow(ResidentExam exam, String reportId) {
    return {
      'id': exam.id,
      'report_id': reportId,
      'tanggal': exam.tanggal,
      'tanggal_lahir': exam.tanggalLahir,
      'nama': exam.nama,
      'nik': exam.nik,
      'usia': exam.usia,
      'alamat': exam.alamat,
      'kategori_keluarga': exam.kategoriKeluarga,
      'bb': exam.bb,
      'tb': exam.tb,
      'lingkar_pinggang': exam.lingkarPinggang,
      'tensi': exam.tensi,
      'lila': exam.lila,
      'lika': exam.lika,
      'gula_darah': exam.gulaDarah,
      'keluhan': exam.keluhan,
      'tindak_lanjut': exam.tindakLanjut,
      'foto_path': exam.fotoPath,
      'custom_fields': exam.customFields,
    };
  }

  static ResidentExam _rowToExam(Map<String, dynamic> row) {
    return ResidentExam(
      id: row['id'] as String? ?? '',
      tanggal: row['tanggal'] as String? ?? '',
      tanggalLahir: row['tanggal_lahir'] as String? ?? '',
      nama: row['nama'] as String? ?? '',
      nik: row['nik'] as String? ?? '',
      usia: row['usia'] as String? ?? '',
      alamat: row['alamat'] as String? ?? '',
      kategoriKeluarga: row['kategori_keluarga'] as String? ?? '',
      bb: row['bb'] as String? ?? '',
      tb: row['tb'] as String? ?? '',
      lingkarPinggang: row['lingkar_pinggang'] as String? ?? '',
      tensi: row['tensi'] as String? ?? '',
      lila: row['lila'] as String? ?? '',
      lika: row['lika'] as String? ?? '',
      gulaDarah: row['gula_darah'] as String? ?? '',
      keluhan: List<String>.from(row['keluhan'] as List? ?? []),
      tindakLanjut: List<String>.from(row['tindak_lanjut'] as List? ?? []),
      fotoPath: row['foto_path'] as String?,
      customFields: row['custom_fields'] != null
          ? Map<String, String>.from(row['custom_fields'] as Map)
          : {},
    );
  }

  /// Cari data pasien di seluruh cloud (semua user).
  /// Mengembalikan list Map yang berisi exam data + info pemilik laporan.
  static Future<List<Map<String, dynamic>>> globalSearchExams(String query) async {
    try {
      if (query.trim().isEmpty) return [];

      final q = query.trim().toLowerCase();

      // Cari resident_exams yang cocok (nama, nik, atau alamat)
      // Gunakan left join ke reports untuk ambil pemilik
      final results = await _client
          .from('resident_exams')
          .select('*, reports(id, no, user_nama, user_puskesmas)')
          .or('nama.ilike.%$q%,nik.ilike.%$q%,alamat.ilike.%$q%')
          .limit(50);

      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      debugPrint('[SupabaseService] globalSearchExams error: $e');
      return [];
    }
  }

  /// Ambil SEMUA data pasien dari cloud (semua kader) tanpa filter.
  /// Digunakan untuk mode global yang langsung tampil saat aktif.
  static Future<List<Map<String, dynamic>>> globalGetAllExams() async {
    try {
      final results = await _client
          .from('resident_exams')
          .select('*, reports(id, no, user_nama, user_puskesmas)')
          .order('tanggal', ascending: false)
          .limit(300);
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      debugPrint('[SupabaseService] globalGetAllExams error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // ADMIN METHODS
  // ─────────────────────────────────────────────

  /// Ambil role user dari tabel profiles.
  static Future<String> fetchUserRole(String userId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return (profile?['role'] as String?) ?? 'user';
    } catch (e) {
      debugPrint('[SupabaseService] fetchUserRole error: $e');
      return 'user';
    }
  }

  /// Admin: Ambil semua user dari tabel profiles.
  static Future<List<Map<String, dynamic>>> adminGetAllUsers() async {
    try {
      final results = await _client
          .from('profiles')
          .select('id, username, email, nama, puskesmas, role')
          .order('nama', ascending: true);
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      debugPrint('[SupabaseService] adminGetAllUsers error: $e');
      return [];
    }
  }

  /// Admin: Ubah role user.
  static Future<String?> adminUpdateUserRole(String userId, String newRole) async {
    try {
      await _client.from('profiles').update({'role': newRole}).eq('id', userId);
      return null;
    } catch (e) {
      return _translateError(e.toString());
    }
  }

  /// Admin: Update profil user (nama, email, puskesmas).
  static Future<String?> adminUpdateProfile(String userId, {String? nama, String? email, String? puskesmas}) async {
    try {
      final updates = <String, dynamic>{};
      if (nama != null) updates['nama'] = nama;
      if (email != null) updates['email'] = email;
      if (puskesmas != null) updates['puskesmas'] = puskesmas;
      if (updates.isEmpty) return null;
      await _client.from('profiles').update(updates).eq('id', userId);
      return null;
    } catch (e) {
      return _translateError(e.toString());
    }
  }

  /// Admin: Ganti password user via RPC function.
  /// Membutuhkan SQL function 'admin_change_user_password' di Supabase.
  /// Jika belum ada, fallback ke reset password via email.
  static Future<String?> adminChangePassword(String userId, String newPassword) async {
    try {
      // Coba via RPC function (paling aman dan benar)
      await _client.rpc('admin_change_user_password', params: {
        'target_user_id': userId,
        'new_password': newPassword,
      });
      return null;
    } catch (e) {
      final errMsg = e.toString().toLowerCase();
      // Jika RPC belum dibuat, beri instruksi jelas
      if (errMsg.contains('function') && (errMsg.contains('does not exist') || errMsg.contains('not found') || errMsg.contains('could not find'))) {
        return 'Fitur ganti password belum aktif.\n\n'
            'Jalankan SQL berikut di Supabase SQL Editor:\n\n'
            'CREATE OR REPLACE FUNCTION admin_change_user_password(target_user_id UUID, new_password TEXT)\n'
            'RETURNS VOID AS \$\$\n'
            'BEGIN\n'
            '  UPDATE auth.users SET encrypted_password = crypt(new_password, gen_salt(\'bf\')) WHERE id = target_user_id;\n'
            'END;\n'
            '\$\$ LANGUAGE plpgsql SECURITY DEFINER;';
      }
      return _translateError(e.toString());
    }
  }

  /// Admin: Ambil semua laporan dari semua user.
  static Future<List<Map<String, dynamic>>> adminGetAllReports() async {
    try {
      final results = await _client
          .from('reports')
          .select('id, no, created_at, user_id, user_nama, user_puskesmas')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      debugPrint('[SupabaseService] adminGetAllReports error: $e');
      return [];
    }
  }

  /// Admin: Hitung total baris di resident_exams.
  static Future<int> adminCountExams() async {
    try {
      final result = await _client.from('resident_exams').select('id');
      return (result as List).length;
    } catch (e) {
      debugPrint('[SupabaseService] adminCountExams error: $e');
      return 0;
    }
  }

  /// Admin: Ambil detail exam dari satu report.
  static Future<List<Map<String, dynamic>>> adminGetReportExams(String reportId) async {
    try {
      final results = await _client
          .from('resident_exams')
          .select()
          .eq('report_id', reportId)
          .order('nama', ascending: true);
      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      debugPrint('[SupabaseService] adminGetReportExams error: $e');
      return [];
    }
  }

  /// Admin: Update data pasien (exam) di cloud.
  static Future<String?> adminUpdateExam(String examId, Map<String, dynamic> updates) async {
    if (currentUserId == null) return 'Sesi login telah berakhir. Silakan login ulang.';
    try {
      // Sanitize string values
      final sanitized = Map<String, dynamic>.from(updates);
      sanitized.removeWhere((key, value) => key == 'id' || key == 'report_id'); // Cegah overwrite ID
      
      final result = await _client
          .from('resident_exams')
          .update(sanitized)
          .eq('id', examId)
          .select();
      debugPrint('[SupabaseService] adminUpdateExam result: ${result.length} rows affected');
      if (result.isEmpty) {
        return 'Data tidak berubah. Kemungkinan diblokir oleh RLS policy.\n\n'
            'Jalankan SQL berikut di Supabase SQL Editor:\n\n'
            'CREATE POLICY "allow_update_exams" ON public.resident_exams\n'
            'FOR UPDATE USING (true) WITH CHECK (true);';
      }
      return null;
    } catch (e) {
      debugPrint('[SupabaseService] adminUpdateExam error: $e');
      return _translateError(e.toString());
    }
  }

  /// Admin: Hapus laporan (dan exam terkait via CASCADE).
  static Future<String?> adminDeleteReport(String reportId) async {
    if (currentUserId == null) return 'Sesi login telah berakhir. Silakan login ulang.';
    try {
      // Hapus resident_exams dulu (jika tidak pakai CASCADE)
      await _client.from('resident_exams').delete().eq('report_id', reportId);
      // Lalu hapus report-nya
      await _client.from('reports').delete().eq('id', reportId);
      return null;
    } catch (e) {
      debugPrint('[SupabaseService] adminDeleteReport error: $e');
      return _translateError(e.toString());
    }
  }

  /// Admin: List semua file di bucket photos.
  static Future<List<Map<String, dynamic>>> adminListPhotos() async {
    try {
      final files = await _client.storage.from('photos').list(
        searchOptions: const SearchOptions(sortBy: SortBy(column: 'created_at', order: 'desc')),
      );
      // Filter placeholder files
      final realFiles = files.where((f) => f.name != '.emptyFolderPlaceholder' && f.name.isNotEmpty).toList();
      debugPrint('[SupabaseService] adminListPhotos: ${realFiles.length} files found');
      for (final f in realFiles) {
        debugPrint('  -> ${f.name} (id: ${f.id})');
      }
      return realFiles.map((f) => <String, dynamic>{
        'name': f.name,
        'id': f.id,
        'size': f.metadata?['size'] ?? 0,
        'created_at': f.createdAt ?? f.metadata?['lastModified'] ?? '',
        'url': _client.storage.from('photos').getPublicUrl(f.name),
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseService] adminListPhotos error: $e');
      return [];
    }
  }

  /// Admin: Hapus foto dari storage.
  static Future<String?> adminDeletePhoto(String fileName) async {
    try {
      debugPrint('[SupabaseService] Mencoba hapus foto: "$fileName"');
      final result = await _client.storage.from('photos').remove([fileName]);
      debugPrint('[SupabaseService] adminDeletePhoto result count: ${result.length}');
      if (result.isEmpty) {
        // Supabase returns empty list when delete is blocked by RLS
        return 'Gagal menghapus foto. Pastikan bucket "photos" punya policy DELETE untuk authenticated users.\n\n'
            'Buka Supabase → Storage → photos → Policies → Tambah policy:\n'
            'Operation: DELETE\n'
            'Target roles: authenticated\n'
            'Policy: USING (true)';
      }
      return null;
    } catch (e) {
      debugPrint('[SupabaseService] adminDeletePhoto error: $e');
      return _translateError(e.toString());
    }
  }
}
