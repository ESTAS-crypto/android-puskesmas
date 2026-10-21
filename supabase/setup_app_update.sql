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

-- 6. Setup Storage Bucket untuk file APK rilis
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'app_releases',
    'app_releases',
    true,
    104857600, -- Maksimal 100 MB per APK
    ARRAY['application/vnd.android.package-archive', 'application/octet-stream']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 104857600;

-- 7. Policy Storage agar semua pengguna bisa mendownload file APK
DROP POLICY IF EXISTS "Public Download APK" ON storage.objects;
CREATE POLICY "Public Download APK"
ON storage.objects FOR SELECT
USING (bucket_id = 'app_releases');

-- Policy Storage agar penguploadan APK diizinkan
DROP POLICY IF EXISTS "Allow Upload APK" ON storage.objects;
CREATE POLICY "Allow Upload APK"
ON storage.objects FOR INSERT
TO authenticated, anon
WITH CHECK (bucket_id = 'app_releases');

DROP POLICY IF EXISTS "Allow Update APK" ON storage.objects;
CREATE POLICY "Allow Update APK"
ON storage.objects FOR UPDATE
TO authenticated, anon
USING (bucket_id = 'app_releases');

