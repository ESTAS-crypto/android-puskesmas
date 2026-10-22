# Redesain "Laporan Kunjungan Rumah" — Fase 1

> Status: **belum dikompilasi/dites** (tidak ada Flutter SDK di lingkungan saya).
> Referensi **Mobbin tidak terpakai**: server Mobbin menolak akses karena butuh paket berbayar.
> Arah desain berasal dari pola umum aplikasi kesehatan/lapangan, bukan dari screenshot Mobbin.

## 1. Temuan audit (kode lama)

| # | Temuan | Dampak | Perbaikan |
|---|---|---|---|
| 1 | Putih di atas teal `#00BFA6` = kontras **2.3:1**; putih di atas oranye/merah muda lebih buruk | Gagal WCAG AA (min 4.5:1), sulit dibaca di bawah matahari | Tombol terisi `#0B7F6C` (**4.9:1**); teal terang `#4CC9AE` hanya untuk ikon/tautan di latar gelap (8.7:1) |
| 2 | Teks "hint" `#6B7A8C` di kartu = **3.2:1** | Gagal AA | `#8FA2AB` (≥ 6:1) |
| 3 | 4 kartu menu 4 warna gradasi berbeda (teal, ungu, oranye, magenta) | Terkesan ramai/"norak", tidak ada hierarki | Satu aksen. Warna lain hanya untuk status |
| 4 | Dashboard `Column` + `Spacer` tanpa scroll | Overflow di HP kecil, terutama saat menu admin muncul | `ListView` + pull-to-refresh |
| 5 | Transisi layar ditulis ulang 3× di dashboard, layar lain pakai default | Tidak konsisten | Satu `AppPageTransitionsBuilder` di tema, semua rute ikut |
| 6 | Animasi masuk pakai `Opacity` di dalam `AnimatedBuilder` per elemen | Boros (saveLayer), tidak hormati "kurangi animasi" | Satu controller + `FadeTransition`, hormati `disableAnimations` |
| 7 | Tombol hapus pasien 20px, tanpa label | Target sentuh terlalu kecil, TalkBack tidak membaca | 44px + tooltip, hapus dengan animasi + **Urungkan** |
| 8 | Dialog konfirmasi generik ("Keluar?", "Hapus Data Pasien?") | Tombol tidak jelas | Salinan tombol berupa aksi; draf pakai bottom sheet |
| 9 | Label input terpisah dari field (`_buildLabel`) | Label hilang di pembaca layar, form login lompat saat mode daftar | `labelText` + morphing tinggi/pudar saat ganti mode |
| 10 | Font lewat `google_fonts` runtime di app *offline-first* | Peluang font berganti di peluncuran pertama tanpa internet | Fase 2: bundel font di `assets/` |

## 2. Token desain

Warna (semua ada di `AppTheme`; nama lama jadi alias):

| Token | Nilai | Pemakaian |
|---|---|---|
| `bg` | `#0F1A1E` | Latar |
| `surface` / `surfaceRaised` | `#162329` / `#1D2D34` | Kartu / input |
| `outline` | `#2A3B43` | Garis |
| `accent` | `#4CC9AE` | Ikon, tautan, fokus |
| `primaryDeep` | `#0B7F6C` | Tombol terisi (teks putih) |
| `text` / `textMuted` / `textFaint` | `#EAF1F0` / `#A9B8BC` / `#8FA2AB` | 14:1 / 7.9:1 / 6:1 |
| `success` `warning` `error` `info` | `#5FCB8A` `#F2B35E` `#FF8A80` `#7AA7FF` | Status saja |

Tipografi: **Plus Jakarta Sans** (dirancang di Jakarta, enak untuk teks Indonesia). Skala: 24/20/16/14/12.
Jarak: 4 · 8 · 12 · 16 · 20 · 24 · 32. Radius: 10 · 14 · 20 · 28.

## 3. Spesifikasi gerak (`AppMotion`)

| Token | Nilai | Dipakai untuk |
|---|---|---|
| `instant` | 100 ms | Respons sentuh (skala 0.97–0.98) |
| `fast` | 180 ms | Toggle, ganti ikon, tombol loading |
| `medium` | 300 ms | Kartu menciut, buka/tutup field, transisi layar |
| `slow` | 520 ms | Angka naik, koreografi masuk |
| `decelerate` | `Cubic(.05,.7,.1,1)` | Elemen **masuk** |
| `accelerate` | `Cubic(.3,0,.8,.15)` | Elemen **keluar** |
| `standard` | `Cubic(.2,0,0,1)` | Perubahan ukuran/posisi |

Aturan: gerak hanya untuk (a) menjawab sentuhan, (b) menunjukkan apa yang berubah, (c) satu koreografi masuk per layar.
Tidak ada animasi hias yang berulang. Semua hormati pengaturan "kurangi animasi" Android.

| Elemen | Pemicu | Animasi |
|---|---|---|
| Pindah layar | `Navigator.push` | Layar baru memudar + geser 7%, layar lama geser −5% (parallax), 300 ms |
| Dashboard | Buka | Header → hero → statistik → akses cepat → terbaru, jeda 80 ms, naik 16 px |
| Angka statistik | Data dimuat / berubah | Naik dari 0 / menyesuaikan, 520 ms |
| Kartu / tombol | Tekan | Skala 0.97–0.98 + ripple + haptic ringan |
| Tombol simpan | `loading` | Label ↔ spinner (pudar + skala) |
| Login ↔ Daftar | Ketuk "Daftar" | Field email & profil buka/tutup (tinggi + pudar), subjudul berganti |
| Kartu pasien | Ditambah | Pudar + naik 12 px |
| Kartu pasien | Dihapus | Menciut 300 ms → snackbar **Urungkan** |
| Kartu pasien | Diseret | Terangkat (skala 1.02 + bayangan) |
| Penghitung pasien | Jumlah berubah | Pil berganti dengan skala + pudar |

## 4. Aksesibilitas (ringkas, WCAG 2.1 AA)

- Kontras teks & ikon ≥ 4.5:1 di semua token baru.
- Target sentuh ≥ 44 px (`AppIconButton`, tombol hapus/seret, `TextButton` min 48×44).
- Semua kartu bisa diklik punya `semanticLabel` yang dibaca utuh ("Laporan nomor 12, 3 pasien…").
- Galat login memakai `liveRegion` agar dibacakan TalkBack.
- Ikon tanpa teks punya `tooltip`.
- Belum dicek: urutan fokus keyboard, skala font 200%, layar lama (lihat fase 2).

## 5. Salinan (UX copy)

| Dulu | Sekarang |
|---|---|
| "Keluar?" | "Keluar dari akun?" — tombol **Batal** / **Keluar** |
| "Lanjutkan Draf?" (dialog) | Bottom sheet — **Lanjutkan draf** / **Hapus draf & mulai baru** |
| "Tambahkan minimal 1 data pasien dulu!" | "Tambahkan minimal 1 pasien sebelum menyimpan." |
| "Belum ada data pasien / Tekan '+ Tambah Pasien'" | "Belum ada pasien" + tombol **Tambah pasien pertama** |
| Menu "Generate Dokumen" | "Dokumen" — "Ekspor ke PDF atau DOCX" |

## 6. File yang berubah

```
lib/theme/app_theme.dart            (ditulis ulang; nama lama tetap sebagai alias)
lib/theme/motion.dart               (BARU)
lib/widgets/ui/ui.dart              (BARU: AppCard, AppButton, AppIconButton, StatusPill,
                                     SectionTitle, EmptyState, CountUp, StaggerScope/StaggerIn)
lib/screens/dashboard_screen.dart   (didesain ulang; logika bisnis sama)
lib/screens/report_form_screen.dart (didesain ulang; hapus + urungkan, bar simpan menempel)
lib/screens/login_screen.dart       (hanya build(); logika login/daftar/Google/reset tidak disentuh)
```

Layar yang **belum** didesain ulang tapi otomatis ikut palet & transisi baru:
riwayat, admin, custom roles, form pasien, splash, sukses, setup profil Google, dialog changelog.

## 7. Fase 2 (usulan urutan)

1. `report_history_screen.dart` (2.2k baris): chip filter, pencarian dengan animasi, daftar dengan `SliverAnimatedList`, skeleton.
2. `resident_exam_form_screen.dart`: bagi jadi langkah (Identitas → Pemeriksaan → Keluhan → Tindak lanjut) dengan indikator progres.
3. `success_screen.dart` + `splash_screen.dart`: satu momen animasi yang rapi, bukan banyak efek.
4. Bundel font Plus Jakarta Sans di `assets/` (`GoogleFonts.config.allowRuntimeFetching = false`).
5. Tema terang: tampilan gelap sulit dibaca di bawah matahari saat kunjungan lapangan. Perlu migrasi konstanta statis ke token berbasis `context`.
6. `admin_panel_screen.dart` (2.3k baris): pecah jadi tab/komponen.
7. Hapus `DashboardHeader` lama di `role_badge.dart` (sekarang tidak dipakai).

## 8. Ikon kustom (baru)

- 40 ikon duotone digambar khusus: kisi 24px, garis 2px membulat, isian 18% dari warna yang sama.
- `lib/widgets/ui/app_icons.dart`: `AppGlyph.home`, `AppIcon(AppGlyph.home, size: 22, color: ...)`. Pengganti `Icon`, dan juga menerima `IconData` biasa.
- `AppButton`, `AppIconButton`, `StatusPill`, `EmptyState` kini menerima `AppGlyph` maupun `IconData`.
- **Wajib:** tambahkan paket SVG: `flutter pub add flutter_svg`.
- `assets/icons/*.svg` adalah file desain (untuk Figma/Inkscape). Aplikasi tidak memerlukannya.
- Changelog: emoji di awal teks dibuang saat tampil, diganti kotak ikon (Baru / Peningkatan / Perbaikan).
- Belum diganti: ikon Material di layar riwayat, admin, form pasien, dan dialog update (ikut diganti di fase berikutnya).

## 9. Splash v2

- `lib/screens/splash_screen.dart` ditulis ulang. Total 2,8 dtk. Tidak lagi memakai Lottie (`assets/hospital.json` dan paket `lottie` boleh dihapus kalau tidak dipakai layar lain).
- Waktu tunggu lama ±7,5 dtk (6,5 dtk fixed + 0,6 dtk keluar + 0,5 dtk transisi) → 2,8 dtk + 0,3 dtk transisi. Pemeriksaan login paralel, update role dibatasi 3 dtk.
- Versi di bawah memakai `UpdateService.currentVersion`.
- Samakan splash sistem Android supaya tidak ada kilatan: `flutter pub add --dev flutter_native_splash`, lalu di `pubspec.yaml`:

```yaml
flutter_native_splash:
  color: "#D6ECFA"
  image: assets/icon.png
  android_12:
    color: "#D6ECFA"
    image: assets/icon.png
    icon_background_color: "#FFFFFF"
```
Jalankan `dart run flutter_native_splash:create`.
