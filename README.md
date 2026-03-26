<div align="center">
  <h1>🏥 Laporan Kunjungan</h1>
  <p>Aplikasi Pencatatan Medis & Kunjungan Pasien berbasis Mobile dengan dukungan Offline-First.</p>

  <!-- Badges -->
  <p>
    <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
    <img src="https://img.shields.io/badge/Firebase-%23039BE5.svg?style=for-the-badge&logo=Firebase&logoColor=white" alt="Firebase" />
  </p>
</div>

---

## 📖 Deskripsi
**Laporan Kunjungan** adalah aplikasi berbasis Flutter yang dirancang untuk memudahkan tenaga medis atau petugas kesehatan dalam mencatat data pasien, hasil pemeriksaan, keluhan, dan tindak lanjut. Aplikasi ini dilengkapi dengan kemampuan **Offline-First**, sehingga pencatatan dapat dilakukan kapan saja dan di mana saja tanpa khawatir kehilangan koneksi internet.

## ✨ Fitur Utama
- 📱 **Manajemen Data Pasien:** Pencatatan identitas pasien yang lengkap dan terstruktur.
- 🩺 **Hasil Pemeriksaan:** Dokumentasi detail mengenai keluhan, hasil pemeriksaan fisik/medis, dan tindak lanjut.
- 📶 **Offline-First (Firebase Firestore):** Aplikasi tetap dapat digunakan tanpa internet. Data akan disinkronisasi ke server secara otomatis saat perangkat kembali *online*.
- 📄 **Export Laporan (PDF & DOCX):** Cetak hasil pemeriksaan pasien langsung dari aplikasi ke dalam format PDF atau Word dengan rapi.
- 🎨 **Modern & Responsive UI:** Antarmuka yang bersih, mudah digunakan, dan dilengkapi animasi interaktif.

## 🛠️ Teknologi yang Digunakan
- **Framework:** [Flutter](https://flutter.dev/)
- **Bahasa Pemrograman:** [Dart](https://dart.dev/)
- **Backend/Database:** Firebase Firestore
- **Export Engine:** `pdf` & `docx_template`

## 🚀 Memulai Pengembangan (Getting Started)

Ikuti langkah-langkah di bawah ini untuk menjalankan aplikasi di lingkungan pengembangan lokal Anda:

### Prasyarat
- Flutter SDK (Versi terbaru disarankan)
- Android Studio / VS Code
- Akun Firebase (untuk konfigurasi Firestore)

### Instalasi

1. **Clone repository ini:**
   ```bash
   git clone https://github.com/username/laporan_kunjungan.git
   ```

2. **Masuk ke folder projek:**
   ```bash
   cd laporan_kunjungan
   ```

3. **Unduh semua dependensi:**
   ```bash
   flutter pub get
   ```

4. **Jalankan aplikasi:**
   ```bash
   flutter run
   ```

> **Catatan:** Pastikan Anda telah mengonfigurasi `google-services.json` (untuk Android) atau `GoogleService-Info.plist` (untuk iOS) dari Firebase Console ke dalam projek ini agar fitur *database* dapat berjalan dengan baik.

## 📸 Tangkapan Layar (Screenshots)
*(Ganti URL gambar di bawah ini dengan screenshot asli aplikasi Anda setelah di-upload ke GitHub)*

| Beranda | Form Pasien | Export Laporan |
| :---: | :---: | :---: |
| <img src="https://via.placeholder.com/200x400.png?text=Beranda" width="200"/> | <img src="https://via.placeholder.com/200x400.png?text=Form+Pasien" width="200"/> | <img src="https://via.placeholder.com/200x400.png?text=Export" width="200"/> |

---
<div align="center">
  Dibuat dengan ❤️ menggunakan Flutter.
</div>
