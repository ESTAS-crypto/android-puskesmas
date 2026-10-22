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
import time
from datetime import datetime, timezone
import requests

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

def set_app_version(new_version, new_code=None):
    """Otomatis sinkronkan nomor versi baru ke seluruh file proyek"""
    old_version, old_code = get_app_version()
    if new_code is None:
        try:
            new_code = str(int(old_code) + 1)
        except ValueError:
            new_code = "1"

    # 1. Update pubspec.yaml
    pubspec_path = "pubspec.yaml"
    if os.path.exists(pubspec_path):
        with open(pubspec_path, "r", encoding="utf-8") as f:
            content = f.read()
        content = re.sub(r"version:\s*[^\n]+", f"version: {new_version}+{new_code}", content)
        with open(pubspec_path, "w", encoding="utf-8") as f:
            f.write(content)

    # 2. Update lib/services/update_service.dart
    update_svc_path = os.path.join("lib", "services", "update_service.dart")
    if os.path.exists(update_svc_path):
        with open(update_svc_path, "r", encoding="utf-8") as f:
            content = f.read()
        content = re.sub(r"static const String currentVersion = '[^']+';", f"static const String currentVersion = '{new_version}';", content)
        content = re.sub(r"static const int currentVersionCode = \d+;", f"static const int currentVersionCode = {new_code};", content)
        with open(update_svc_path, "w", encoding="utf-8") as f:
            f.write(content)

    # 3. Update lib/widgets/changelog_dialog.dart
    changelog_path = os.path.join("lib", "widgets", "changelog_dialog.dart")
    if os.path.exists(changelog_path):
        with open(changelog_path, "r", encoding="utf-8") as f:
            content = f.read()
        content = re.sub(r"static const String _currentVersion = '[^']+';", f"static const String _currentVersion = '{new_version}';", content)
        with open(changelog_path, "w", encoding="utf-8") as f:
            f.write(content)

    print("\n" + "="*60)
    print("🏷️  VERSI APLIKASI BERHASIL DIPERBARUI!")
    print("="*60)
    print(f"📌 Versi Sebelumnya : v{old_version} (Build {old_code})")
    print(f"🚀 Versi Baru       : v{new_version} (Build {new_code})")
    print("📁 File yang otomatis disinkronkan:")
    print("   • pubspec.yaml")
    print("   • lib/services/update_service.dart")
    print("   • lib/widgets/changelog_dialog.dart")
    print("="*60)


def run_command(cmd):
    """Jalankan command shell secara realtime"""
    print(f"\n⚙️ Menjalankan: {' '.join(cmd)}\n" + "-"*50)
    process = subprocess.Popen(cmd, shell=True)
    process.communicate()
    return process.returncode

class AnimatedUploadProgress:
    """Wrapper file streaming dengan animasi progress bar, kecepatan realtime, dan estimasi hitungan mundur"""
    def __init__(self, file_path):
        self.file_path = file_path
        self.file_obj = open(file_path, "rb")
        self.total_size = os.path.getsize(file_path)
        self.uploaded_bytes = 0
        self.start_time = time.time()
        self.last_update_time = 0

    def read(self, size=-1):
        chunk = self.file_obj.read(size)
        self.uploaded_bytes += len(chunk)
        self._render_bar()
        return chunk

    def _render_bar(self):
        now = time.time()
        if now - self.last_update_time < 0.15 and self.uploaded_bytes < self.total_size:
            return
        self.last_update_time = now

        pct = (self.uploaded_bytes / self.total_size) * 100 if self.total_size > 0 else 0
        elapsed = now - self.start_time
        speed = self.uploaded_bytes / elapsed if elapsed > 0 else 0
        speed_mb = speed / (1024 * 1024)
        up_mb = self.uploaded_bytes / (1024 * 1024)
        tot_mb = self.total_size / (1024 * 1024)

        eta = (self.total_size - self.uploaded_bytes) / speed if speed > 0 else 0
        eta_str = f"{int(eta)} dtk" if eta < 60 else f"{int(eta // 60)}m {int(eta % 60)}s"

        bar_len = 22
        filled = int(bar_len * (self.uploaded_bytes / self.total_size)) if self.total_size > 0 else 0
        bar = "█" * filled + "░" * (bar_len - filled)

        icons = ["🚀", "⚡", "🛸", "✨"]
        icon = icons[int(now * 4) % len(icons)]

        sys.stdout.write(
            f"\r{icon} [{bar}] {pct:5.1f}% | {up_mb:4.1f}/{tot_mb:4.1f} MB | ⚡ {speed_mb:4.1f} MB/s | Sisa: {eta_str:6s} ⏳"
        )
        sys.stdout.flush()

    def __len__(self):
        return self.total_size

    def close(self):
        self.file_obj.close()

def publish_to_supabase(apk_path, version_name, version_code):
    """Upload APK ke Supabase Storage & perbarui config app_update secara otomatis"""
    supabase_url = "https://pndkpooxkbmkgmcgqygl.supabase.co"
    anon_key = "sb_publishable_3HttqlKQ2iv-CLGJyv-AjA_-AmS663B"
    bucket = "app_releases"
    file_name = os.path.basename(apk_path)

    print("\n" + "="*60)
    # Pastikan version_name selalu sinkron dengan nama file APK yang diupload
    match = re.search(r'_v([0-9\.]+)\.apk', file_name)
    if match:
        file_ver = match.group(1)
        if file_ver != version_name:
            print(f"⚠️ Menyesuaikan versi rilis dari v{version_name} ke v{file_ver} (sesuai file APK {file_name})")
            version_name = file_ver

    txt_path = "release_notes.txt"
    notes = ""
    if os.path.exists(txt_path):
        try:
            with open(txt_path, "r", encoding="utf-8") as f:
                file_content = f.read().strip()
            if file_content:
                print(f"📄 Ditemukan file '{txt_path}' berisi catatan rilis:")
                preview_lines = file_content.splitlines()
                for line in preview_lines[:4]:
                    print(f"   {line}")
                if len(preview_lines) > 4:
                    print(f"   ... ({len(preview_lines)} baris total)")
                choice = input(f"📝 Gunakan catatan rilis dari '{txt_path}'? (Y/n / atau ketik path file .txt lain) [Default: Y]: ").strip()
                if choice.lower() in ("", "y", "ya", "yes"):
                    notes = file_content
                elif choice.lower().endswith(".txt") and os.path.exists(choice):
                    with open(choice, "r", encoding="utf-8") as f:
                        notes = f.read().strip()
                elif choice.lower() not in ("n", "no"):
                    notes = choice
        except Exception as e:
            print(f"⚠️ Gagal membaca '{txt_path}': {e}")

    if not notes:
        user_input = input(f"📝 Masukkan Catatan Rilis v{version_name} (atau ketik nama file .txt / Enter untuk default): ").strip()
        if user_input.lower().endswith(".txt") and os.path.exists(user_input):
            with open(user_input, "r", encoding="utf-8") as f:
                notes = f.read().strip()
        elif user_input:
            notes = user_input
        else:
            notes = f"Pembaruan versi {version_name} dengan peningkatan kinerja dan stabilitas."

    print(f"\n⏳ Meng-upload {file_name} ke Supabase Storage...")
    print("   Mohon tunggu (animasi upload sedang berjalan)...")

    try:
        import requests
        wrapped_file = AnimatedUploadProgress(apk_path)

        upload_url = f"{supabase_url}/storage/v1/object/{bucket}/{file_name}"
        headers = {
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "Content-Type": "application/vnd.android.package-archive",
            "x-upsert": "true"
        }

        res = requests.post(upload_url, data=wrapped_file, headers=headers)
        wrapped_file.close()

        print("\n" + "-"*60)
        if res.status_code not in (200, 201):
            print(f"❌ Gagal upload ke storage (HTTP {res.status_code}): {res.text}")
            print("💡 Pastikan Anda sudah menjalankan SQL di supabase/setup_app_update.sql pada Supabase SQL Editor.")
            return

        public_download_url = f"{supabase_url}/storage/v1/object/public/{bucket}/{file_name}"
        print(f"✅ File APK berhasil di-upload ke Cloud!")
        print(f"🔗 Public URL: {public_download_url}")

        # Animasi hitungan mundur peluncuran rilis
        print("\n⏳ Mempersiapkan peluncuran rilis update ke seluruh kader...")
        for count in range(3, 0, -1):
            sys.stdout.write(f"\r✨ Mengaktifkan notifikasi pembaruan dalam {count}... ")
            sys.stdout.flush()
            time.sleep(1)
        sys.stdout.write("\r✨ Mengaktifkan notifikasi pembaruan... SELESAI!            \n")
        sys.stdout.flush()

        # Update database app_config
        db_url = f"{supabase_url}/rest/v1/app_config"
        db_headers = {
            "apikey": anon_key,
            "Authorization": f"Bearer {anon_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates"
        }
        from datetime import datetime, timezone
        payload = {
            "key": "app_update",
            "value": {
                "version": version_name,
                "version_code": int(version_code),
                "download_url": public_download_url,
                "release_notes": notes,
                "is_mandatory": False,
                "released_at": datetime.now(timezone.utc).isoformat()
            }
        }

        res_db = requests.post(db_url, json=payload, headers=db_headers)
        if res_db.status_code in (200, 201, 204):
            print("\n" + "="*60)
            print("🎉 SUKSES BESAR! PEMBARUAN RESMI DIRILIS!")
            print("="*60)
            print(f"📢 Versi Baru : v{version_name} (Build Code {version_code})")
            print(f"📲 Semua HP kader yang membuka aplikasi akan langsung")
            print(f"   menerima dialog update otomatis ala Play Store!")
            print("="*60)

            # 🧹 AUTO CLEANUP: Otomatis hapus file APK versi lama agar storage Supabase tetap hemat
            print("\n🧹 Memeriksa & membersihkan file APK lama di Supabase Storage...")
            try:
                list_url = f"{supabase_url}/storage/v1/object/list/{bucket}"
                list_res = requests.post(
                    list_url,
                    json={"prefix": "", "limit": 100, "sortBy": {"column": "created_at", "order": "desc"}},
                    headers={"apikey": anon_key, "Authorization": f"Bearer {anon_key}", "Content-Type": "application/json"}
                )
                if list_res.status_code == 200:
                    files = list_res.json()
                    apk_files = [f for f in files if f.get("name", "").endswith(".apk")]
                    # Pertahankan maksimal 2 versi terbaru (versi saat ini + 1 versi sebelumnya untuk backup)
                    MAX_KEEP = 2
                    if len(apk_files) > MAX_KEEP:
                        files_to_delete = apk_files[MAX_KEEP:]
                        del_names = [f["name"] for f in files_to_delete]
                        del_url = f"{supabase_url}/storage/v1/object/{bucket}"
                        del_res = requests.delete(
                            del_url,
                            json={"prefixes": del_names},
                            headers={"apikey": anon_key, "Authorization": f"Bearer {anon_key}", "Content-Type": "application/json"}
                        )
                        if del_res.status_code in (200, 204):
                            print(f"🗑️ Otomatis menghapus {len(del_names)} file APK versi lama: {', '.join(del_names)}")
                            print("✨ Kuota Storage Supabase Anda tetap aman, bersih, dan hemat kuota!")
                        else:
                            print(f"⚠️ Melewati penghapusan versi lama: {del_res.text}")
                    else:
                        print(f"✨ Storage Supabase optimal (tersimpan {len(apk_files)} versi APK, batas maksimal aman: {MAX_KEEP}).")
            except Exception as e_clean:
                print(f"⚠️ Melewati pembersihan storage: {e_clean}")

        else:
            print(f"\n⚠️ Upload APK berhasil, tapi gagal update status DB: {res_db.text}")
            print(f"💡 Anda bisa masukkan URL ini secara manual di Admin Panel aplikasi:")
            print(f"   {public_download_url}")

    except Exception as e:
        print(f"\n❌ Terjadi kesalahan saat publikasi: {e}")

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
    print("\n  [5] 🏷️  Ganti / Naikkan Versi Aplikasi (Otomatis sinkron ke semua file)")
    print("  [0] ❌ Keluar")
    print("-" * 60)

    pilihan = input("Masukkan pilihan Anda (1/2/3/4/5/0) [Default: 1]: ").strip()
    if not pilihan:
        pilihan = "1"

    if pilihan == "0":
        print("Operasi dibatalkan.")
        return

    if pilihan == "4":
        run_command(["flutter", "doctor"])
        return

    if pilihan == "5":
        new_v = input(f"\n🏷️  Masukkan versi baru [Versi saat ini: v{version_name}]: ").strip()
        if new_v:
            set_app_version(new_v)
        return

    # Pastikan dependensi up-to-date
    print("\n📦 Memeriksa dependensi package (flutter pub get)...")
    run_command(["flutter", "pub", "get"])

    if pilihan == "1":
        print(f"\n📌 Versi APK saat ini: v{version_name} (Build Code: {version_code})")
        tanya_versi = input("Ketik versi baru jika ingin dinaikkan (contoh: 2.7.6), atau tekan [Enter] untuk tetap: ").strip()
        if tanya_versi:
            set_app_version(tanya_versi)
            version_name, version_code = get_app_version()

        print("\n🔨 Memulai proses compile APK Universal...")
        print("⏳ Mohon tunggu beberapa saat (biasanya 1-2 menit)...")
        code = run_command(["flutter", "build", "apk", "--release", "--target-platform", "android-arm,android-arm64", "--android-skip-build-dependency-validation"])
        
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

            # Opsi otomatis upload ke Supabase
            print("\n" + "-"*60)
            tanya_upload = input("🚀 Mau langsung upload & rilis pembaruan ke Supabase Cloud? (y/n) [Default: n]: ").strip().lower()
            if tanya_upload in ("y", "yes"):
                publish_to_supabase(dest_apk, version_name, version_code)

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
