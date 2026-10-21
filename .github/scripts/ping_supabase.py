import os
import sys
import time
import json
import urllib.request
import urllib.error
import datetime

# Pastikan console output mendukung karakter Unicode (emoji) di semua platform (Windows/Linux)
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

PROJECT_REF = "pndkpooxkbmkgmcgqygl"
ANON_KEY = "sb_publishable_3HttqlKQ2iv-CLGJyv-AjA_-AmS663B"

def send_discord_notification(webhook_url, embed):
    """Kirim notifikasi embed ke Discord Webhook."""
    if not webhook_url:
        print("[Notice] DISCORD_WEBHOOK_URL tidak ditemukan. Lewati pengiriman Discord.")
        return

    payload = {"embeds": [embed]}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Supabase-Guardian/2.0"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            print(f"[Discord] Webhook berhasil dikirim, HTTP: {resp.getcode()}")
    except Exception as e:
        print(f"[Discord] Gagal mengirim Webhook: {e}")

def ping_endpoint(url, headers, timeout=12):
    """Ping satu endpoint HTTP dengan urllib dan ukur latency-nya."""
    req = urllib.request.Request(url, headers=headers)
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            elapsed_ms = int((time.time() - start) * 1000)
            return resp.getcode(), elapsed_ms, resp.read().decode("utf-8", errors="ignore"), None
    except urllib.error.HTTPError as e:
        elapsed_ms = int((time.time() - start) * 1000)
        body = ""
        try:
            body = e.read().decode("utf-8", errors="ignore")
        except Exception:
            pass
        return e.code, elapsed_ms, body, str(e)
    except Exception as e:
        elapsed_ms = int((time.time() - start) * 1000)
        return 0, elapsed_ms, "", str(e)

def perform_keepalive_ping(retries=3):
    """
    Lakukan ping ganda (Database via PostgREST + Auth Service) dengan cache-buster
    dan mekanisme retry jika terjadi cold start.
    """
    headers = {
        "apikey": ANON_KEY,
        "Authorization": f"Bearer {ANON_KEY}",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "User-Agent": "Supabase-KeepAlive-Guardian/2.0"
    }

    for attempt in range(1, retries + 1):
        db_url = f"https://{PROJECT_REF}.supabase.co/rest/v1/profiles?select=id&limit=1"
        auth_url = f"https://{PROJECT_REF}.supabase.co/auth/v1/health"

        print(f"[Ping] Percobaan {attempt}/{retries}...")
        status_db, latency_db, body_db, err_db = ping_endpoint(db_url, headers)
        status_auth, latency_auth, _, _ = ping_endpoint(auth_url, headers)

        is_paused = (
            status_db == 503
            or "paused" in body_db.lower()
            or "paused" in str(err_db).lower()
        )

        if (200 <= status_db < 300 or status_db == 404) and (200 <= status_auth < 300):
            print(f"[Ping] Sukses! DB Latency: {latency_db}ms, Auth Latency: {latency_auth}ms")
            return {
                "success": True,
                "is_paused": False,
                "latency_db": latency_db,
                "latency_auth": latency_auth,
                "error": None
            }

        if is_paused:
            print("[Ping] Supabase terdeteksi PAUSED (HTTP 503 / Paused response)!")
            return {
                "success": False,
                "is_paused": True,
                "latency_db": latency_db,
                "latency_auth": latency_auth,
                "error": err_db or "Project is paused"
            }

        print(f"[Ping] Percobaan {attempt} gagal: DB status={status_db}, err={err_db}. Menunggu 4 detik...")
        if attempt < retries:
            time.sleep(4)

    return {
        "success": False,
        "is_paused": False,
        "latency_db": 0,
        "latency_auth": 0,
        "error": err_db or "Connection timeout / Unreachable"
    }

def get_project_status_via_api(access_token):
    """Cek status project via Supabase Management API."""
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "User-Agent": "Supabase-KeepAlive-Guardian/2.0"
        },
        method="GET"
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            return data.get("status")  # Misal: 'ACTIVE_HEALTHY', 'PAUSED', 'RESTORING'
    except Exception as e:
        print(f"[Management API] Gagal cek status project: {e}")
        return None

def trigger_auto_resume(access_token):
    """
    Panggil endpoint resmi Supabase Management API untuk me-restore / unpause project:
    POST https://api.supabase.com/v1/projects/{ref}/restore
    """
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/restore"
    req = urllib.request.Request(
        url,
        data=b"{}",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "User-Agent": "Supabase-KeepAlive-Guardian/2.0"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            code = resp.getcode()
            print(f"[Management API] Restore dipicu! HTTP Response: {code}")
            return True, f"HTTP {code}"
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode()
        except Exception:
            pass
        print(f"[Management API] Error saat restore: HTTP {e.code} - {body}")
        return False, f"HTTP {e.code}: {body}"
    except Exception as e:
        print(f"[Management API] Gagal memanggil restore: {e}")
        return False, str(e)

def main():
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
    supabase_access_token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()

    # Timezone WIB (Asia/Jakarta = UTC+7)
    tz_wib = datetime.timezone(datetime.timedelta(hours=7))
    now_wib = datetime.datetime.now(tz_wib)
    next_ping = now_wib + datetime.timedelta(hours=12) # Interval 12 jam
    pause_deadline = now_wib + datetime.timedelta(days=7)

    fmt_short = "%d %b %Y, %H.%M"
    now_str = now_wib.strftime(fmt_short)
    next_str = next_ping.strftime(fmt_short)
    deadline_str = pause_deadline.strftime(fmt_short)
    footer_date_str = now_wib.strftime("%d/%m/%Y %H.%M")

    # 1. Jalankan ping diagnostik ke database & auth
    ping_result = perform_keepalive_ping(retries=3)

    # 2. Jika gagal atau jika token ada, kita bisa pastikan status via Management API
    api_status = None
    if supabase_access_token:
        api_status = get_project_status_via_api(supabase_access_token)
        print(f"[Management API] Status project saat ini: {api_status}")
        if api_status == "PAUSED":
            ping_result["is_paused"] = True

    # 3. KASUS A: Supabase terdeteksi PAUSED / Down dan ada token -> AUTO-RESUME!
    if ping_result["is_paused"] or (not ping_result["success"] and api_status == "PAUSED"):
        print("\n==========================================")
        print("🚨 DETEKSI: Supabase ter-pause!")
        print("==========================================")

        if supabase_access_token:
            print("🚀 Memicu AUTO-RESUME via Supabase Management API...")
            restore_ok, restore_msg = trigger_auto_resume(supabase_access_token)

            if restore_ok:
                print("⏳ Menunggu 20 detik untuk proses pemulihan (spin-up)...")
                time.sleep(20)

                # Coba re-ping hingga 5 kali untuk verifikasi
                revived = False
                for i in range(1, 6):
                    print(f"[Verify] Cek status ke-{i}...")
                    verify_ping = perform_keepalive_ping(retries=1)
                    if verify_ping["success"]:
                        revived = True
                        break
                    time.sleep(6)

                if revived:
                    # Discord Embed: Auto-Resume SUKSES
                    embed = {
                        "title": "🔄 Supabase Auto-Resumed & Restored!",
                        "description": (
                            "| **Database sebelumnya ter-pause**, namun **Guardian berhasil melakukan AUTO-RESUME otomatis!**\n\n"
                            "```\nSTATUS: ONLINE & RESTORED (KEMBALI AKTIF)\n```"
                        ),
                        "color": 0x3498DB,  # Ocean Azure Blue
                        "fields": [
                            {"name": "⚡ Latency Baru", "value": f"`{verify_ping['latency_db']}ms`", "inline": True},
                            {"name": "🕒 Waktu Pulih (WIB)", "value": f"`{now_str}`", "inline": True},
                            {"name": "📅 Auto-Ping Berikutnya", "value": f"`{next_str}`", "inline": True},
                            {"name": "🤖 Auto-Resume Action", "value": "Berhasil dipulihkan via Management API", "inline": False},
                            {"name": "⌛ Pause Deadline Baru", "value": f"`{deadline_str}` *(7 hari dari sekarang)*", "inline": False},
                            {"name": "🔄 Auto-Ping Interval", "value": "Setiap **12 jam** (2x sehari)", "inline": False}
                        ],
                        "footer": {"text": f"ESTAS Puskesmas • Supabase Guardian • {footer_date_str}"}
                    }
                    send_discord_notification(webhook_url, embed)
                    print("✅ Proyek berhasil dipulihkan dan kembali normal!")
                    sys.exit(0)
                else:
                    # Discord Embed: Restore dipicu tapi masih proses initializing
                    embed = {
                        "title": "⏳ Supabase Sedang Proses Auto-Resume",
                        "description": (
                            "| Perintah restore telah dikirim ke Supabase Management API.\n"
                            "Database sedang proses spin-up dan akan segera aktif dalam beberapa menit."
                        ),
                        "color": 0xF39C12,  # Amber Orange
                        "fields": [
                            {"name": "🕒 Waktu Trigger", "value": f"`{now_str}`", "inline": True},
                            {"name": "ℹ️ Info", "value": "Proses restore memakan waktu 1-3 menit", "inline": True}
                        ],
                        "footer": {"text": f"ESTAS Puskesmas • Supabase Guardian • {footer_date_str}"}
                    }
                    send_discord_notification(webhook_url, embed)
                    sys.exit(0)
            else:
                # Restore API gagal
                embed = {
                    "title": "🚨 Gagal Memicu Auto-Resume Supabase",
                    "description": f"| Percobaan auto-resume via API gagal: `{restore_msg}`.\nSilakan buka Supabase Dashboard untuk resume manual.",
                    "color": 0xE74C3C,
                    "footer": {"text": f"ESTAS Puskesmas • Supabase Guardian • {footer_date_str}"}
                }
                send_discord_notification(webhook_url, embed)
                sys.exit(1)
        else:
            # Token tidak tersedia -> Infokan user cara pasang token
            embed = {
                "title": "🚨 Supabase Ter-pause! (Token Belum Diset)",
                "description": (
                    "| **PERINGATAN:** Project terdeteksi **PAUSED**.\n"
                    "Auto-resume belum aktif karena secret `SUPABASE_ACCESS_TOKEN` belum dipasang di GitHub Secrets.\n\n"
                    "```\nSTATUS: DOWN - PAUSED\n```"
                ),
                "color": 0xE74C3C,
                "fields": [
                    {
                        "name": "💡 Solusi Segera",
                        "value": "1. Buka [Supabase Dashboard](https://supabase.com/dashboard) dan klik **Resume project**.",
                        "inline": False
                    },
                    {
                        "name": "🛡️ Agar Kedepannya Auto-Resume Otomatis",
                        "value": (
                            "1. Buat token di [Supabase Access Tokens](https://supabase.com/dashboard/account/tokens)\n"
                            "2. Masukkan ke GitHub: **Repo Settings → Secrets and variables → Actions** dengan nama `SUPABASE_ACCESS_TOKEN`."
                        ),
                        "inline": False
                    }
                ],
                "footer": {"text": f"ESTAS Puskesmas • Supabase Guardian • {footer_date_str}"}
            }
            send_discord_notification(webhook_url, embed)
            sys.exit(1)

    # 4. KASUS B: Ping Sukses (Normal Keep-Alive)
    if ping_result["success"]:
        guardian_status = "🛡️ Aktif (Auto-Resume Ready)" if supabase_access_token else "⚠️ Belum Pasang Access Token"

        embed = {
            "title": "✅ Supabase Keep-Alive Report",
            "description": "| Project berhasil di-ping! Timer pause **sudah di-reset** ke 7 hari.\n\n```\nOnline & Healthy\n```",
            "color": 0x2ECC71,  # Sleek Emerald Green
            "fields": [
                {
                    "name": "⚡ Latency",
                    "value": f"DB: `{ping_result['latency_db']}ms` | Auth: `{ping_result['latency_auth']}ms`",
                    "inline": True
                },
                {
                    "name": "🕒 Ping Time (WIB)",
                    "value": f"`{now_str}`",
                    "inline": True
                },
                {
                    "name": "📅 Next Auto-Ping",
                    "value": f"`{next_str}`",
                    "inline": True
                },
                {
                    "name": "⌛ Pause Deadline",
                    "value": f"`{deadline_str}` *(7 hari dari sekarang)*",
                    "inline": False
                },
                {
                    "name": "🔄 Auto-Ping Interval",
                    "value": "Setiap **12 jam** (2x sehari)",
                    "inline": True
                },
                {
                    "name": "🛡️ Auto-Resume",
                    "value": guardian_status,
                    "inline": True
                }
            ],
            "footer": {
                "text": f"ESTAS Puskesmas • Supabase Guardian • {footer_date_str}"
            }
        }
        send_discord_notification(webhook_url, embed)
        print("✅ Keep-alive berhasil dijalankan.")
        sys.exit(0)

    # 5. KASUS C: Ping Gagal karena network timeout / unreachable umum
    embed = {
        "title": "🚨 Supabase Keep-Alive Report",
        "description": f"| **PERINGATAN:** Endpoint tidak merespons!\n*Detail:* `{ping_result['error']}`\n\n```\nDOWN - Unreachable\n```",
        "color": 0xE74C3C,  # Crimson Red
        "fields": [
            {"name": "🕒 Ping Time (WIB)", "value": f"`{now_str}`", "inline": True},
            {"name": "📅 Next Auto-Ping", "value": f"`{next_str}`", "inline": True},
            {"name": "⚠️ Status", "value": "Server tidak merespons setelah 3x percobaan", "inline": False}
        ],
        "footer": {
            "text": f"ESTAS Puskesmas • Supabase Guardian • {footer_date_str}"
        }
    }
    send_discord_notification(webhook_url, embed)
    sys.exit(1)

if __name__ == "__main__":
    main()
