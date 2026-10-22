# Status implementasi

> Semua kode di paket ini **belum dikompilasi dan belum dijalankan** (dibuat tanpa Flutter SDK). Anggap "ditulis", bukan "teruji".

## Sudah ditulis
- Token, tema, gerak: `lib/theme/app_theme.dart`, `lib/theme/motion.dart` — **masih GELAP**
- Komponen bersama: `lib/widgets/ui/ui.dart`; ikon kustom: `lib/widgets/ui/app_icons.dart` (butuh `flutter_svg`)
- Layar: Beranda, Laporan baru, Masuk, Splash; changelog (ikon saja)

## Belum
Lihat kolom Status di `.agents/skills/puskesmas-redesign/SKILL.md`. Juga: banner koneksi, pesan singkat, dialog, galat/izin/suara.

## Keputusan penting
- Desain yang disetujui = **tema TERANG** (biru langit/laut). Kode saat ini gelap → **Fase 1 wajib: ubah ke terang**.
- Logo asli: `assets/icon.png` (teal, latar putih). Dipakai di splash dalam kotak putih. Jangan diganti.
- Offline bukan galat: amber lembut, bukan merah.

## Cara membalik ke tema terang (Fase 1)
1. Ubah nilai di `AppTheme` sesuai tabel di `.agents/rules/design-rules.md`. Nama konstanta lama (`primaryDark`, `cardDark`, dst.) tetap sebagai alias agar layar lama ikut berubah.
2. `ThemeData`: `Brightness.light`, `ColorScheme.light(...)`, status bar ikon gelap, `systemNavigationBarColor` terang.
3. Cari dan tangani: `Colors.white` / `Colors.white.withValues(...)` yang dipakai sebagai warna **permukaan atau teks di atas permukaan** (di layar lama bisa tak terlihat di latar terang). Teks putih di atas tombol biru tetap benar.
4. Periksa `AppTheme.accent`/`accentTeal`: di tema terang dipakai untuk ikon/teks → `#0A64A8`.
5. Jalankan semua layar dan cek kontras. Laporkan layar yang rusak.
