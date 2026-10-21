-- ====================================================================
-- SOLUSI PERBAIKAN SECURITY ADVISOR SUPABASE:
-- "RLS Disabled in Public" pada tabel public.custom_roles
-- Project: laporan-kunjungan (pndkpooxkbmkgmcgqygl)
-- ====================================================================

-- 1. Aktifkan Row Level Security (RLS) pada tabel custom_roles
ALTER TABLE public.custom_roles ENABLE ROW LEVEL SECURITY;

-- 2. Bersihkan policy lama jika ada (mencegah error duplikasi)
DROP POLICY IF EXISTS "Allow read custom_roles" ON public.custom_roles;
DROP POLICY IF EXISTS "Allow authenticated insert custom_roles" ON public.custom_roles;
DROP POLICY IF EXISTS "Allow authenticated update custom_roles" ON public.custom_roles;
DROP POLICY IF EXISTS "Allow authenticated delete custom_roles" ON public.custom_roles;

-- 3. Policy SELECT: Izinkan pembacaan data role untuk user anon & authenticated
-- (Aman karena role hanya berisi metadata: nama, warna, ikon, dan permission)
CREATE POLICY "Allow read custom_roles"
ON public.custom_roles
FOR SELECT
TO anon, authenticated
USING (true);

-- 4. Policy INSERT: Hanya user yang login (authenticated) yang boleh menambah role baru
CREATE POLICY "Allow authenticated insert custom_roles"
ON public.custom_roles
FOR INSERT
TO authenticated
WITH CHECK (true);

-- 5. Policy UPDATE: Hanya user yang login (authenticated) yang boleh mengubah role
CREATE POLICY "Allow authenticated update custom_roles"
ON public.custom_roles
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 6. Policy DELETE: Hanya user yang login (authenticated) yang boleh menghapus role
CREATE POLICY "Allow authenticated delete custom_roles"
ON public.custom_roles
FOR DELETE
TO authenticated
USING (true);
