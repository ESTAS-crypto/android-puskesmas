#!/usr/bin/env python3
"""
====================================================================
🏥 BUILD WIZARD - APLIKASI LAPORAN KUNJUNGAN PUSKESMAS
====================================================================
Script otomatis untuk meng-compile aplikasi Flutter menjadi file APK 
yang siap digunakan dan diinstal di semua jenis HP Android.
====================================================================
"""

import os
import sys
import shutil
import subprocess
import re

# Pastikan output mendukung UTF-8 di Windows console
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

def get_app_version():
    """Baca nomor versi dari pubspec.yaml"""
    pubspec_path = "pubspec.yaml"
    if not os.path.exists(pubspec_path):
        return "1.0.0", "1"
    
    version_str = "1.0.0"
    build_num = "1"
    with open(pubspec_path, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("version:"):
                raw = line.split(":", 1)[1].strip().replace('"', '').replace("'", "")
                if "+" in raw:
                    version_str, build_num = raw.split("+", 1)
                else:
                    version_str = raw
                break
    return version_str, build_num

def run_command(cmd):
    """Jalankan command shell secara realtime"""
    print(f"\n⚙️ Menjalankan: {' '.join(cmd)}\n" + "-"*50)
    process = subprocess.Popen(cmd, shell=True)
    process.communicate()
    return process.returncode

def main():
    version_name, version_code = get_app_version()
    releases_dir = os.path.abspath("releases")
    os.makedirs(releases_dir, exist_ok=True)

    print("\n" + "="*60)
    print("🏥 BUILD WIZARD - APLIKASI LAPORAN KUNJUNGAN PUSKESMAS")
    print("="*60)
    print(f"📌 Versi Terdeteksi: v{version_name} (Build Code: {version_code})")
    print(f"📁 Folder Output   : {releases_dir}")
    print("="*60)
    print("\nPILIH OPSI BUILD:")
    print("  [1] 🚀 APK Universal (Paling Direkomendasikan)")
    print("      • 1 File APK yang bisa diinstall di SEMUA jenis & merk HP Android")
    print("      • Sangat cocok untuk update otomatis (OTA) / kirim ke kader")
    print("\n  [2] 📦 APK Split per-Arsitektur (arm64, armeabi-v7a)")
    print("      • Menghasilkan file APK dengan ukuran lebih kecil per tipe HP")
    print("\n  [3] 🌐 App Bundle (.aab)")
    print("      • Format khusus untuk upload ke Google Play Store")
    print("\n  [4] 🩺 Periksa Kesehatan Lingkungan Flutter (flutter doctor)")
    print("  [0] ❌ Keluar")
    print("-" * 60)

    pilihan = input("Masukkan pilihan Anda (1/2/3/4/0) [Default: 1]: ").strip()
    if not pilihan:
        pilihan = "1"

    if pilihan == "0":
        print("Operasi dibatalkan.")
        return

    if pilihan == "4":
        run_command(["flutter", "doctor"])
        return

    # Pastikan dependensi up-to-date
    print("\n📦 Memeriksa dependensi package (flutter pub get)...")
    run_command(["flutter", "pub", "get"])

    if pilihan == "1":
        print("\n🔨 Memulai proses compile APK Universal...")
        print("⏳ Mohon tunggu beberapa saat (biasanya 1-2 menit)...")
        code = run_command(["flutter", "build", "apk", "--release", "--android-skip-build-dependency-validation"])
        
        if code != 0:
            print("\n❌ Build gagal! Periksa pesan error di atas.")
            return

        src_apk = os.path.join("build", "app", "outputs", "flutter-apk", "app-release.apk")
        if os.path.exists(src_apk):
            dest_name = f"Laporan_Kunjungan_v{version_name}.apk"
            dest_apk = os.path.join(releases_dir, dest_name)
            shutil.copy2(src_apk, dest_apk)
            
            size_mb = os.path.getsize(dest_apk) / (1024 * 1024)
            print("\n" + "="*60)
            print("🎉 BUILD BERHASIL! (100% SUKSES)")
            print("="*60)
            print(f"📱 File APK : {dest_name}")
            print(f"💾 Ukuran   : {size_mb:.2f} MB")
            print(f"📂 Lokasi   : {dest_apk}")
            print("="*60)
            print("\n💡 File APK ini siap di-upload ke Supabase Storage (bucket app_releases)")
            print("   atau langsung dikirim ke HP kader/petugas puskesmas!")

            # Buka folder otomatis di Windows Explorer
            try:
                os.system(f'explorer "{releases_dir}"')
            except Exception:
                pass
        else:
            print(f"\n⚠️ File output tidak ditemukan di {src_apk}")

    elif pilihan == "2":
        print("\n🔨 Memulai compile APK Split ABI...")
        code = run_command(["flutter", "build", "apk", "--release", "--split-per-abi", "--android-skip-build-dependency-validation"])
        if code == 0:
            src_dir = os.path.join("build", "app", "outputs", "flutter-apk")
            copied = 0
            for f in os.listdir(src_dir):
                if f.endswith(".apk") and f != "app-release.apk":
                    shutil.copy2(os.path.join(src_dir, f), os.path.join(releases_dir, f))
                    copied += 1
            print(f"\n✅ Berhasil! {copied} file APK disalin ke folder: {releases_dir}")
            try:
                os.system(f'explorer "{releases_dir}"')
            except Exception:
                pass

    elif pilihan == "3":
        print("\n🔨 Memulai compile App Bundle (.aab)...")
        code = run_command(["flutter", "build", "appbundle", "--release", "--android-skip-build-dependency-validation"])
        if code == 0:
            src_aab = os.path.join("build", "app", "outputs", "bundle", "release", "app-release.aab")
            if os.path.exists(src_aab):
                dest_aab = os.path.join(releases_dir, f"Laporan_Kunjungan_v{version_name}.aab")
                shutil.copy2(src_aab, dest_aab)
                print(f"\n✅ Berhasil! File AAB tersimpan di: {dest_aab}")
                try:
                    os.system(f'explorer "{releases_dir}"')
                except Exception:
                    pass

if __name__ == "__main__":
    main()
