-- ====================================================================
-- SETUP FITUR IN-APP AUTO-UPDATE (OTA UPDATE)
-- Project: laporan-kunjungan (pndkpooxkbmkgmcgqygl)
-- ====================================================================

-- 1. Pastikan tabel app_config ada
CREATE TABLE IF NOT EXISTS public.app_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Aktifkan Row Level Security (RLS)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- 3. Policy SELECT: Izinkan pembacaan config untuk semua pengguna (anon & authenticated)
-- Sangat penting agar aplikasi bisa memeriksa update saat pertama kali dibuka
DROP POLICY IF EXISTS "Allow read app_config" ON public.app_config;
CREATE POLICY "Allow read app_config"
ON public.app_config
FOR SELECT
TO anon, authenticated
USING (true);

-- 4. Policy INSERT & UPDATE: Hanya user yang login (admin/developer) yang boleh mengubah config
DROP POLICY IF EXISTS "Allow authenticated upsert app_config" ON public.app_config;
CREATE POLICY "Allow authenticated upsert app_config"
ON public.app_config
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 5. Contoh konfigurasi awal app_update (opsional / template)
-- Anda juga bisa mengaturnya langsung dari Admin Panel di dalam aplikasi!
INSERT INTO public.app_config (key, value)
VALUES (
    'app_update',
    jsonb_build_object(
        'version', '2.7.5',
        'version_code', 9,
        'download_url', '',
        'release_notes', 'Versi stabil awal.',
        'is_mandatory', false,
        'released_at', NOW()
    )
)
ON CONFLICT (key) DO NOTHING;
