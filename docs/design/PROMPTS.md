# Prompt siap tempel (urut kerjakan)

Jalankan SATU per percakapan. Minta rencana dulu, baru kode. Commit setelah tiap fase.

## Fase 0 — Pasang paket
```
Baca AGENTS.md, .agents/rules/design-rules.md, docs/design/STATUS.md.
Tugas: jalankan `flutter pub add flutter_svg`, lalu `flutter pub get` dan `flutter analyze`.
Perbaiki HANYA error kompilasi dari file yang ada di lib/theme, lib/widgets/ui, dan layar yang diubah (dashboard, report_form, login, splash, changelog_dialog). Jangan ubah logika bisnis.
Laporkan semua error yang kamu temukan dan cara memperbaikinya. Jangan bilang "sudah diuji" kecuali kamu menjalankan aplikasinya.
```

## Fase 1 — Tema terang
```
Ikuti bagian "Cara membalik ke tema terang" di docs/design/STATUS.md dan tabel token di .agents/rules/design-rules.md.
Tampilkan rencana dulu: daftar file yang memakai Colors.white atau warna hardcode yang akan bermasalah di latar terang.
Setelah disetujui, ubah. Lalu jalankan flutter analyze dan beri daftar layar yang perlu dicek mata.
```

## Fase 2 — Banner koneksi, pesan, dialog
```
Pakai skill puskesmas-redesign. Kerjakan: lib/widgets/connectivity_banner.dart sesuai docs/design/mockups/status-canvas/Main.dc.html dan status-prototype.html (4 status: offline, sinkron, selesai, gagal).
Pertahankan logika: pengecekan koneksi, StorageService.syncPendingReports, timer 4 detik. Hanya ganti tampilan dan gerak (masuk 300 ms decelerate, keluar 180 ms accelerate).
Lalu buat helper bersama untuk SnackBar (Pesan.dc.html) dan dialog konfirmasi bottom sheet (Konfirmasi.dc.html) di lib/widgets/ui/, dan ganti SnackBar/AlertDialog di dashboard dan report_form. Layar lain nanti.
```

## Fase 3 — Splash native
```
Ikuti bagian 9 di docs/design/REDESIGN.md: pasang flutter_native_splash (dev dependency) dengan warna #D6ECFA dan assets/icon.png, jalankan generator, pastikan tidak ada kilatan warna saat pindah dari splash sistem ke splash Flutter. Jangan ubah splash_screen.dart kecuali ada bug.
```

## Fase 4 — Riwayat
```
Pakai skill puskesmas-redesign untuk layar Riwayat (mockup: main-canvas/Riwayat.dc.html). Pertahankan pencarian lokal/global, ekspor PDF/DOCX, dan semua logika. Pakai SliverAnimatedList atau AnimatedList untuk perubahan daftar. Tambahkan status Terkirim/Menunggu sinyal pada tiap kartu.
```

## Fase 5 — Admin (3 tab), Role custom
```
Pakai skill puskesmas-redesign untuk admin_panel_screen.dart (mockup AdminUser/AdminLaporan/AdminFoto) lalu custom_roles_screen.dart (Roles.dc.html). File sangat besar: pecah jadi widget per tab di file terpisah TANPA mengubah logika. Kerjakan satu tab per commit.
```

## Fase 6 — Form pasien
```
Pakai skill puskesmas-redesign untuk resident_exam_form_screen.dart (FormPasien.dc.html): bagian Identitas, Hasil pemeriksaan, Keluhan, Tindak lanjut, Foto geotag dengan bar progres dan tombol simpan menempel. Pertahankan auto-complete nama, input suara, geotag, dan draf otomatis. Tambahkan state izin lokasi ditolak dan suara tidak tersedia (Galat.dc.html).
```

## Fase 7 — Sukses, profil Google, update dialog
```
Pakai skill puskesmas-redesign untuk success_screen.dart (Sukses.dc.html + SuksesOffline.dc.html), google_profile_setup_screen.dart (Google.dc.html), dan widgets/update_dialog.dart (Update.dc.html, 3 tahap).
```

## Fase 8 — Performa
```
Jalankan aplikasi di HP asli dengan `flutter run --profile`. Buka DevTools › Performance, lakukan: buka app → splash → login → beranda → buat laporan → tambah/hapus pasien → riwayat. Catat frame yang merah (> 16 ms) dan penyebabnya. Perbaiki yang terukur (hindari Opacity pada subtree besar, tambah RepaintBoundary, kurangi saveLayer). Tampilkan sebelum/sesudah. Jangan menebak: perbaiki hanya yang terukur.
```
