-- ==============================================================================
-- UstamBurada - Veritabanı Şeması ve PostGIS Entegrasyonu
-- ==============================================================================

-- 1. EKLENTİLER (EXTENSIONS)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ==============================================================================
-- 2. ENUM TİPLERİ
-- ==============================================================================
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('musteri', 'usta');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE usta_kategori AS ENUM ('elektrik', 'cilingir', 'tesisat');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE cagri_durumu AS ENUM ('bekliyor', 'kabul_edildi', 'yolda', 'tamamlandi', 'iptal');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ==============================================================================
-- 3. TABLOLAR
-- ==============================================================================

-- 3.1 PROFILES TABLOSU
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT UNIQUE NOT NULL,
    role user_role NOT NULL,
    full_name TEXT NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3.2 USTALAR TABLOSU
CREATE TABLE IF NOT EXISTS public.ustalar (
    id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    kategori usta_kategori NOT NULL,
    konum GEOGRAPHY(Point, 4326) NOT NULL,
    is_online BOOLEAN NOT NULL DEFAULT false,
    servis_ucreti NUMERIC(10, 2) NOT NULL DEFAULT 500.00,
    puan NUMERIC(3, 2) NOT NULL DEFAULT 5.00,
    sub_merchant_id TEXT,
    CONSTRAINT check_servis_ucreti CHECK (servis_ucreti >= 300.00 AND servis_ucreti <= 5000.00),
    CONSTRAINT check_puan CHECK (puan >= 0.00 AND puan <= 5.00)
);

-- 3.3 SISTEM AYARLARI TABLOSU (Tekil konfigürasyon satırı)
CREATE TABLE IF NOT EXISTS public.sistem_ayarlari (
    id INT PRIMARY KEY DEFAULT 1,
    komisyon_orani NUMERIC(4, 2) NOT NULL DEFAULT 0.15,
    CONSTRAINT check_single_row CHECK (id = 1),
    CONSTRAINT check_komisyon_orani CHECK (komisyon_orani >= 0.00 AND komisyon_orani <= 1.00)
);

-- Varsayılan komisyon oranını ekle (varsa dokunma)
INSERT INTO public.sistem_ayarlari (id, komisyon_orani)
VALUES (1, 0.15)
ON CONFLICT (id) DO NOTHING;

-- 3.4 CAGRI TABLOSU
CREATE TABLE IF NOT EXISTS public.cagrilar (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    musteri_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    usta_id UUID REFERENCES public.ustalar(id) ON DELETE SET NULL,
    musteri_konum GEOGRAPHY(Point, 4326) NOT NULL,
    adres_tarifi TEXT,
    durum cagri_durumu NOT NULL DEFAULT 'bekliyor',
    usta_hakedis NUMERIC(10, 2),
    komisyon_tutari NUMERIC(10, 2),
    toplam_tutar NUMERIC(10, 2),
    payment_intent_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 4. İNDEKSLEME (PERFORMANS & SPATIAL)
-- ==============================================================================

-- PostGIS GiST İndeksleri
CREATE INDEX IF NOT EXISTS idx_ustalar_konum ON public.ustalar USING GIST (konum);
CREATE INDEX IF NOT EXISTS idx_cagrilar_musteri_konum ON public.cagrilar USING GIST (musteri_konum);

-- Filtreleme ve Sorgu İndeksleri
CREATE INDEX IF NOT EXISTS idx_ustalar_online_kategori ON public.ustalar (kategori, is_online);
CREATE INDEX IF NOT EXISTS idx_cagrilar_musteri_id ON public.cagrilar (musteri_id);
CREATE INDEX IF NOT EXISTS idx_cagrilar_usta_id ON public.cagrilar (usta_id);
CREATE INDEX IF NOT EXISTS idx_cagrilar_durum ON public.cagrilar (durum);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles (phone);

-- ==============================================================================
-- 5. RPC FONKSİYONU: YAKIN USTALARI GETİR
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.yakin_ustalari_getir(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_kategori TEXT,
    p_radius_meter INT DEFAULT 10000
)
RETURNS TABLE (
    usta_id UUID,
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    kategori usta_kategori,
    puan NUMERIC(3, 2),
    konum GEOGRAPHY,
    mesafe_metre DOUBLE PRECISION,
    usta_hakedis NUMERIC(10, 2),
    komisyon_orani NUMERIC(4, 2),
    komisyon_tutari NUMERIC(10, 2),
    toplam_tutar NUMERIC(10, 2)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_user_point GEOGRAPHY;
    v_komisyon_orani NUMERIC(4, 2);
BEGIN
    -- PostGIS ST_MakePoint parametre sırası: (Longitude/X, Latitude/Y)
    v_user_point := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;

    -- Sistem ayarlarından güncel komisyon oranını al (varsayılan 0.15)
    SELECT COALESCE(sa.komisyon_orani, 0.15)
    INTO v_komisyon_orani
    FROM public.sistem_ayarlari sa
    WHERE sa.id = 1;

    IF v_komisyon_orani IS NULL THEN
        v_komisyon_orani := 0.15;
    END IF;

    RETURN QUERY
    SELECT 
        u.id AS usta_id,
        p.full_name,
        p.phone,
        p.avatar_url,
        u.kategori,
        u.puan,
        u.konum,
        ROUND(ST_Distance(u.konum, v_user_point))::DOUBLE PRECISION AS mesafe_metre,
        u.servis_ucreti AS usta_hakedis,
        v_komisyon_orani AS komisyon_orani,
        ROUND(u.servis_ucreti * v_komisyon_orani, 2) AS komisyon_tutari,
        ROUND(u.servis_ucreti * (1 + v_komisyon_orani), 2) AS toplam_tutar
    FROM public.ustalar u
    INNER JOIN public.profiles p ON p.id = u.id
    WHERE u.is_online = true
      AND u.kategori = p_kategori::usta_kategori
      AND ST_DWithin(u.konum, v_user_point, p_radius_meter)
    ORDER BY ST_Distance(u.konum, v_user_point) ASC;
END;
$$;

-- Fonksiyon çalıştırma iznini anon ve authenticated rollerine tanımla
GRANT EXECUTE ON FUNCTION public.yakin_ustalari_getir(DOUBLE PRECISION, DOUBLE PRECISION, TEXT, INT) TO authenticated, anon;

-- ==============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLİTİKALARI
-- ==============================================================================

-- 6.1 PROFILES RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiller kimliği doğrulanmış tüm kullanıcılar tarafından görüntülenebilir
CREATE POLICY "Profilleri tum kullanicilar gorebilir"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

-- Kullanıcılar yalnızca kendi profillerini güncelleyebilir
CREATE POLICY "Kullanicilar kendi profilini guncelleyebilir"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Kullanıcılar yalnızca kendi profil satırını oluşturabilir
CREATE POLICY "Kullanicilar kendi profilini olusturabilir"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 6.2 USTALAR RLS
ALTER TABLE public.ustalar ENABLE ROW LEVEL SECURITY;

-- Çevrimiçi veya kayıtlı ustaları tüm giriş yapmış kullanıcılar arayabilir/görebilir
CREATE POLICY "Ustalar tum kullanicilar tarafindan gorulebilir"
ON public.ustalar
FOR SELECT
TO authenticated
USING (true);

-- Usta sadece kendi profil/usta kaydını güncelleyebilir (online durumu, ücret vb.)
CREATE POLICY "Usta kendi bilgilerini guncelleyebilir"
ON public.ustalar
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Usta kaydını yalnızca ilgili profil sahibi oluşturabilir
CREATE POLICY "Usta kendi kaydini ekleyebilir"
ON public.ustalar
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- 6.3 SISTEM AYARLARI RLS
ALTER TABLE public.sistem_ayarlari ENABLE ROW LEVEL SECURITY;

-- Komisyon oranını authenticated kullanıcılar okuyabilir
CREATE POLICY "Sistem ayarlari okunabilir"
ON public.sistem_ayarlari
FOR SELECT
TO authenticated
USING (true);

-- Sadece service_role güncelleyebilir (Dashboard / Admin API)
-- INSERT/UPDATE politikası tanımlanmadığı için authenticated kullanıcılar yazamaz.

-- 6.4 CAGRI RLS
ALTER TABLE public.cagrilar ENABLE ROW LEVEL SECURITY;

-- Müşteri sadece kendi açtığı çağrıları; Usta ise kendisine atanan veya beklemedeki çağrıları görebilir
CREATE POLICY "Cagrilari sadece ilgili musteri ve usta gorebilir"
ON public.cagrilar
FOR SELECT
TO authenticated
USING (
    auth.uid() = musteri_id 
    OR auth.uid() = usta_id
    OR (durum = 'bekliyor' AND usta_id IS NULL)
);

-- Müşteriler yeni çağrı oluşturabilir
CREATE POLICY "Musteri yeni cagri olusturabilir"
ON public.cagrilar
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = musteri_id);

-- Çağrıyı sadece ilgili müşteri veya usta güncelleyebilir (örneğin durumu 'tamamlandi' veya 'yolda' yapma)
CREATE POLICY "Ilgili musteri ve usta cagriyi guncelleyebilir"
ON public.cagrilar
FOR UPDATE
TO authenticated
USING (
    auth.uid() = musteri_id 
    OR auth.uid() = usta_id
    OR (durum = 'bekliyor' AND usta_id IS NULL)
)
WITH CHECK (
    auth.uid() = musteri_id 
    OR auth.uid() = usta_id
    OR (durum = 'kabul_edildi' AND usta_id = auth.uid())
);
