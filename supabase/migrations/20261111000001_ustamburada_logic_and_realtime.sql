-- ==============================================================================
-- UstamBurada - İş Mantığı, Realtime ve Concurrency Korumaları
-- ==============================================================================

-- 1. AUTH TRIGGER: Yeni kayıt olan kullanıcının profiles tablosuna eklenmesi
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        phone,
        role,
        full_name,
        avatar_url
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.phone, NEW.raw_user_meta_data->>'phone', ''),
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'musteri'::user_role),
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Yeni Kullanıcı'),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    
    RETURN NEW;
END;
$$;

-- Trigger'ı auth.users tablosuna bağla
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 2. USTA KONUM GÜNCELLEME RPC (Mobil GPS Tracking İçin)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.usta_konum_guncelle(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_is_online BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_usta_id UUID := auth.uid();
    v_updated_konum GEOGRAPHY;
BEGIN
    IF v_usta_id IS NULL THEN
        RAISE EXCEPTION 'Yetkisiz erişim. Lütfen giriş yapın.';
    END IF;

    v_updated_konum := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;

    UPDATE public.ustalar
    SET 
        konum = v_updated_konum,
        is_online = COALESCE(p_is_online, is_online)
    WHERE id = v_usta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usta profili bulunamadı.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Konum başarıyla güncellendi',
        'lat', p_lat,
        'lng', p_lng
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.usta_konum_guncelle(DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN) TO authenticated;

-- ==============================================================================
-- 3. ÇAĞRI KABUL ETME RPC (Atomik - Concurrency / Race Condition Önleyici)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cagri_kabul_et(p_cagri_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_usta_id UUID := auth.uid();
    v_cagri RECORD;
    v_servis_ucreti NUMERIC(10, 2);
    v_komisyon_orani NUMERIC(4, 2);
    v_komisyon_tutari NUMERIC(10, 2);
    v_toplam_tutar NUMERIC(10, 2);
BEGIN
    IF v_usta_id IS NULL THEN
        RAISE EXCEPTION 'Yetkisiz erişim.';
    END IF;

    -- Ustanın aktif servis ücretini al
    SELECT servis_ucreti INTO v_servis_ucreti
    FROM public.ustalar
    WHERE id = v_usta_id;

    IF v_servis_ucreti IS NULL THEN
        RAISE EXCEPTION 'Yalnızca kayıtlı ustalar çağrı kabul edebilir.';
    END IF;

    -- Komisyon oranını al
    SELECT komisyon_orani INTO v_komisyon_orani
    FROM public.sistem_ayarlari
    WHERE id = 1;

    v_komisyon_orani := COALESCE(v_komisyon_orani, 0.15);
    v_komisyon_tutari := ROUND(v_servis_ucreti * v_komisyon_orani, 2);
    v_toplam_tutar := ROUND(v_servis_ucreti + v_komisyon_tutari, 2);

    -- Satır kilitleme (FOR UPDATE) ve durum kontrolü ile çağrıyı kabul et
    UPDATE public.cagrilar
    SET 
        durum = 'kabul_edildi',
        usta_id = v_usta_id,
        usta_hakedis = v_servis_ucreti,
        komisyon_tutari = v_komisyon_tutari,
        toplam_tutar = v_toplam_tutar
    WHERE id = p_cagri_id
      AND durum = 'bekliyor'
      AND usta_id IS NULL
    RETURNING * INTO v_cagri;

    IF v_cagri.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Bu çağrı başka bir usta tarafından kabul edilmiş veya iptal edilmiş.'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Çağrı başarıyla kabul edildi.',
        'cagri_id', v_cagri.id,
        'toplam_tutar', v_cagri.toplam_tutar
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cagri_kabul_et(UUID) TO authenticated;

-- ==============================================================================
-- 4. SUPABASE REALTIME REPLICATION TANIMLARI
-- ==============================================================================
-- Müşteri ve usta uygulamalarının anlık canlı bildirim ve konum alması için:
ALTER PUBLICATION supabase_realtime ADD TABLE public.cagrilar;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ustalar;
