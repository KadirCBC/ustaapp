-- ==============================================================================
-- UstamBurada - Değerlendirme (Rating & Reviews) ve Otomatik Puan Güncelleme
-- ==============================================================================

-- 1. DEĞERLENDİRMELER TABLOSU
CREATE TABLE IF NOT EXISTS public.degerlendirmeler (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cagri_id UUID NOT NULL REFERENCES public.cagrilar(id) ON DELETE CASCADE,
    musteri_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    usta_id UUID NOT NULL REFERENCES public.ustalar(id) ON DELETE CASCADE,
    puan INT NOT NULL CHECK (puan >= 1 AND puan <= 5),
    yorum TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT unique_cagri_degerlendirme UNIQUE (cagri_id)
);

-- İndeksler
CREATE INDEX IF NOT EXISTS idx_degerlendirmeler_usta_id ON public.degerlendirmeler(usta_id);
CREATE INDEX IF NOT EXISTS idx_degerlendirmeler_musteri_id ON public.degerlendirmeler(musteri_id);

-- 2. USTANIN ORTALAMA PUANINI HESAPLAYAN VE GÜNCELLEYEN TRIGGER FONKSİYONU
CREATE OR REPLACE FUNCTION public.update_usta_ortalama_puan()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_yeni_ortalama NUMERIC(3, 2);
BEGIN
    -- Ustanın tüm değerlendirmelerindeki ortalama puanını hesapla
    SELECT ROUND(AVG(puan)::numeric, 2)
    INTO v_yeni_ortalama
    FROM public.degerlendirmeler
    WHERE usta_id = NEW.usta_id;

    -- Ustanın puan sütununu güncelle (eğer hiç değerlendirme kalmadıysa varsayılan 5.00)
    UPDATE public.ustalar
    SET puan = COALESCE(v_yeni_ortalama, 5.00)
    WHERE id = NEW.usta_id;

    RETURN NEW;
END;
$$;

-- Trigger'ı bağla
DROP TRIGGER IF EXISTS on_degerlendirme_added ON public.degerlendirmeler;
CREATE TRIGGER on_degerlendirme_added
    AFTER INSERT OR UPDATE ON public.degerlendirmeler
    FOR EACH ROW
    EXECUTE FUNCTION public.update_usta_ortalama_puan();

-- 3. RLS POLİTİKALARI
ALTER TABLE public.degerlendirmeler ENABLE ROW LEVEL SECURITY;

-- Herkes veya oturum açmış kullanıcılar değerlendirmeleri okuyabilir
CREATE POLICY "Degerlendirmeler herkes tarafindan okunabilir"
ON public.degerlendirmeler
FOR SELECT
TO authenticated
USING (true);

-- Yalnızca ilgili çağrının müşterisi değerlendirme yazabilir
CREATE POLICY "Musteri kendi tamamlanan cagrisi icin degerlendirme yapabilir"
ON public.degerlendirmeler
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = musteri_id
    AND EXISTS (
        SELECT 1 FROM public.cagrilar c
        WHERE c.id = cagri_id
          AND c.musteri_id = auth.uid()
          AND c.durum = 'tamamlandi'
    )
);
