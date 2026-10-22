# Aturan desain — tema "Laut & Langit" (TERANG)

Desain yang disetujui adalah **tema terang biru langit/laut**. Kode di repo saat ini masih memakai token GELAP (lihat STATUS.md, tugas Fase 1).

## Token (target)
| Token | Nilai | Pakai |
|---|---|---|
| bg | `#F1F8FD` | Latar. Atas halaman: gradasi dari `#D6ECFA` ke bg sampai ±340 px |
| surface | `#FFFFFF` | Kartu, sheet, banner |
| surfaceRaised | `#EAF3FA` | Input, tombol ikon, bar progres |
| outline | `#D3E4F1` | Garis, pembatas |
| text | `#0B2A40` | Teks utama (14.8:1) |
| textMuted | `#3F5A70` | Teks isi sekunder (7.2:1) |
| textFaint | `#4A667E` | Keterangan, label kecil (≥ 4.6:1) |
| primary | `#0A64A8` | Tombol terisi (teks putih 6.2:1), ikon, tautan, fokus |
| tint | primary 10% | Latar ikon/pil netral |
| success | `#176B40` di atas `rgba(27,127,75,.12)` | Terkirim, berhasil |
| warning | `#8A5200` di atas `rgba(176,106,0,.14)` | Offline, menunggu, peringatan |
| danger | `#B02323` | Hapus, galat (tombol berbahaya terisi `#B02323`) |
| toast | latar `#0B2A40`, teks putih, aksi `#8FD0FF` | Pesan singkat |
| bayangan kartu | `0 1px 2px rgba(11,42,64,.06), 0 8px 20px rgba(10,100,168,.08)` | Kartu |

Font: Plus Jakarta Sans. Ukuran: judul 24/20, sub 18/16, isi 16, kecil minimal 14. Tombol tinggi 52–58 px, radius 14. Kartu radius 20. Hero 24. Sheet 26–28.
Jangan menaruh teks putih di atas warna terang. Satu warna aksen; warna lain hanya untuk status.

## Gerak (AppMotion)
instant 100 ms · fast 180 ms · medium 300 ms · slow 520 ms. Masuk = decelerate `(.05,.7,.1,1)`, keluar = accelerate `(.3,0,.8,.15)`, ubah ukuran = standard `(.2,0,0,1)`.
Tekan kartu/tombol: skala 0.97–0.98 + ripple + haptic ringan. Banner/Toast: masuk 300 ms, keluar 180 ms. Layar: fade + geser 7%, layar lama −5%.
Satu koreografi masuk per layar (StaggerScope, jeda 80 ms, naik 16 px).

## Pola status koneksi
- Offline = **amber lembut**, bukan merah (bukan galat). Ikon `wifiOff`, "Mode offline", "Data tersimpan di HP. Terkirim otomatis saat ada sinyal."
- Online → biru "Kembali online" + bar progres → hijau "N laporan berhasil disinkronkan" → hilang sendiri 4 dtk.
- Gagal kirim: amber, tetap tampil, tombol "Coba lagi".
- Status laporan: pil "Terkirim" (hijau) / "Menunggu sinyal" (amber). Statistik "Belum terkirim" amber saat > 0.

## Pola pesan
- Snackbar: bawah layar, 4 dtk, satu per satu, aksi ≥ 44 px ("Urungkan", "Coba lagi").
- Dialog = bottom sheet. Aksi berbahaya merah, bukan posisi utama. Keluar akun saat ada laporan belum terkirim: tampilkan peringatan khusus.
- Galat: jelaskan apa yang terjadi, bahwa data aman, dan langkah berikutnya.

## Jangan
Emoji; gradasi norak; border-kiri berwarna pada kartu; lebih dari satu aksen; animasi berulang; angka ajaib; teks < 14 px; tombol ikon < 44 px; menampilkan pesan teknis ke pengguna.
