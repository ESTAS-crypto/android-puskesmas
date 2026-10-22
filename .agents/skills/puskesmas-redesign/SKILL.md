---
name: puskesmas-redesign
description: Gunakan saat mendesain ulang atau mengimplementasikan SATU layar/komponen aplikasi Puskesmas Kunjungan Rumah (Flutter) agar sesuai mockup yang disetujui. Memuat peta layar→mockup→file Dart dan langkah kerja.
---

# Mengerjakan satu layar

## Langkah
1. Baca `AGENTS.md`, `.agents/rules/design-rules.md`, `docs/design/STATUS.md`.
2. Cari layar di tabel bawah. Baca mockup-nya (markup HTML: ukuran, teks, warna, susunan) dan, bila ada, prototipe yang bisa digerakkan.
3. Baca file Dart layar itu. Tulis daftar **logika yang harus dipertahankan** (controller, validator, panggilan service, navigasi, state). Jangan diubah.
4. Buat rencana singkat (file yang diubah, komponen ui.dart yang dipakai, komponen baru bila perlu) dan tampilkan SEBELUM menulis kode.
5. Implementasi: ganti hanya lapisan tampilan. Token, komponen bersama, `AppIcon`, `AppMotion`.
6. Tambahkan gerak sesuai spesifikasi (masuk layar, tekan, perubahan status). Hormati reduced motion.
7. Aksesibilitas: target 44 px, label semantik, tooltip, kontras, teks ≥ 14 px.
8. `flutter analyze` → bersih. Jalankan di HP asli dengan `--profile` bila bisa.
9. Laporkan memakai templat di bawah.

## Peta layar
| Layar | Mockup | File Dart | Status |
|---|---|---|---|
| Splash | `mockups/splash.html` | `lib/screens/splash_screen.dart` | ditulis, belum diuji |
| Masuk | `mockups/prototype.html`, `main-canvas/Login.dc.html` | `login_screen.dart` | ditulis (gelap) |
| Beranda | `main-canvas/Main.dc.html`, `status-canvas/BerandaOffline.dc.html` | `dashboard_screen.dart` | ditulis (gelap) |
| Laporan baru | `main-canvas/Form.dc.html` | `report_form_screen.dart` | ditulis (gelap) |
| Form pasien | `main-canvas/FormPasien.dc.html` | `resident_exam_form_screen.dart` | BELUM |
| Riwayat | `main-canvas/Riwayat.dc.html` | `report_history_screen.dart` | BELUM |
| Admin · User/Laporan/Foto | `main-canvas/AdminUser|AdminLaporan|AdminFoto.dc.html` | `admin_panel_screen.dart` | BELUM |
| Role custom | `main-canvas/Roles.dc.html` | `custom_roles_screen.dart` | BELUM |
| Layar sukses | `main-canvas/Sukses.dc.html`, `status-canvas/SuksesOffline.dc.html` | `success_screen.dart` | BELUM |
| Setup profil Google | `main-canvas/Google.dc.html` | `google_profile_setup_screen.dart` | BELUM |
| Changelog | `main-canvas/Changelog.dc.html` | `widgets/changelog_dialog.dart` | ikon saja |
| Dialog update | `main-canvas/Update.dc.html` | `widgets/update_dialog.dart` | BELUM |
| Banner koneksi | `status-canvas/Main.dc.html`, `status-prototype.html` | `widgets/connectivity_banner.dart` | BELUM |
| Pesan singkat | `status-canvas/Pesan.dc.html` | semua `SnackBar` | BELUM |
| Konfirmasi | `status-canvas/Konfirmasi.dc.html` | semua `AlertDialog` | BELUM |
| Galat & izin & suara | `status-canvas/Galat.dc.html` | login, foto, geotag, input suara | BELUM |
| Ikon & lencana | `main-canvas/Ikon.dc.html`, `assets/icons/` | `widgets/ui/app_icons.dart` | ada |

## Templat laporan akhir
```
Layar: ...
File diubah: ...
Logika yang sengaja TIDAK diubah: ...
Komponen bersama yang dipakai / ditambah: ...
flutter analyze: bersih / ada ... (jelaskan)
Dijalankan di HP asli (--profile)? ya/tidak. Frame merah: ...
Belum diverifikasi: ...
```
