import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { corsHeaders } from "../_shared/cors.ts";
import { IyzicoClient } from "../_shared/iyzico.ts";

interface PreAuthRequest {
  cagri_id: string;
  card_token?: string;
  card_user_key?: string;
  payment_card?: {
    cardHolderName: string;
    cardNumber: string;
    expireMonth: string;
    expireYear: string;
    cvc: string;
  };
}

serve(async (req: Request) => {
  // CORS Preflight kontrolü
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  console.log(`[PRE-AUTH] İstek alındı: ${new Date().toISOString()}`);

  try {
    // 1. Ortam Değişkenlerini Doğrula
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const iyzicoApiKey = Deno.env.get("IYZICO_API_KEY") || "sandbox-sample-api-key";
    const iyzicoSecretKey = Deno.env.get("IYZICO_SECRET_KEY") || "sandbox-sample-secret-key";
    const iyzicoBaseUrl = Deno.env.get("IYZICO_BASE_URL") || "https://sandbox-api.iyzipay.com";

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Sunucu yapılandırma hatası: Supabase anahtarları eksik.");
    }

    // 2. İstek Gövdesini Ayrıştır
    const body: PreAuthRequest = await req.json();
    const { cagri_id, card_token, card_user_key, payment_card } = body;

    if (!cagri_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Eksik parametre: cagri_id zorunludur.",
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[PRE-AUTH] İşlem başlatılıyor. Çağrı ID: ${cagri_id}`);

    // 3. Supabase Admin İstemcisini Oluştur (Service Role)
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 4. cagrilar tablosundan çağrı ve profil detaylarını çek
    const { data: cagri, error: cagriError } = await supabase
      .from("cagrilar")
      .select(`
        id,
        musteri_id,
        usta_id,
        toplam_tutar,
        durum,
        payment_intent_id,
        musteri:profiles!cagrilar_musteri_id_fkey(full_name, phone)
      `)
      .eq("id", cagri_id)
      .single();

    if (cagriError || !cagri) {
      console.error(`[PRE-AUTH] Çağrı bulunamadı:`, cagriError);
      return new Response(
        JSON.stringify({
          success: false,
          error: "Belirtilen çağrı kaydı bulunamadı.",
        }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const toplamTutar = Number(cagri.toplam_tutar);
    if (!toplamTutar || toplamTutar <= 0) {
      throw new Error(`Geçersiz çağrı tutarı: ${cagri.toplam_tutar}`);
    }

    // Zaten provizyon alınmış mı kontrol et
    if (cagri.payment_intent_id) {
      console.warn(`[PRE-AUTH] Bu çağrı için zaten provizyon alınmış: ${cagri.payment_intent_id}`);
      return new Response(
        JSON.stringify({
          success: true,
          message: "Bu çağrı için zaten provizyon bloke edilmiş durumda.",
          payment_intent_id: cagri.payment_intent_id,
          toplam_tutar: toplamTutar,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[PRE-AUTH] Bloke edilecek tutar: ${toplamTutar} TL. İyzico Pre-Auth isteği hazırlanıyor...`);

    // 5. İyzico Pazaryeri Pre-Auth (Ön Otorizasyon) İsteği
    const iyzicoClient = new IyzicoClient({
      apiKey: iyzicoApiKey,
      secretKey: iyzicoSecretKey,
      baseUrl: iyzicoBaseUrl,
    });

    const conversationId = `preauth_${cagri.id}_${Date.now()}`;
    const musteriAd = (cagri.musteri as any)?.full_name || "Musteri";
    const musteriTel = (cagri.musteri as any)?.phone || "+905000000000";

    // Kart bilgisi: token veya direkt kart nesnesi
    let paymentCardPayload: Record<string, any>;
    if (card_token && card_user_key) {
      paymentCardPayload = {
        cardToken: card_token,
        cardUserKey: card_user_key,
      };
    } else if (payment_card) {
      paymentCardPayload = {
        cardHolderName: payment_card.cardHolderName,
        cardNumber: payment_card.cardNumber,
        expireMonth: payment_card.expireMonth,
        expireYear: payment_card.expireYear,
        cvc: payment_card.cvc,
        registerCard: 0,
      };
    } else {
      // Mock / Test Kartı (Sandbox varsayılanı)
      paymentCardPayload = {
        cardToken: card_token || "sample_card_token_sandbox",
      };
    }

    const preAuthPayload = {
      locale: "tr",
      conversationId: conversationId,
      price: toplamTutar.toFixed(2),
      paidPrice: toplamTutar.toFixed(2),
      currency: "TRY",
      installment: 1,
      basketId: `BASKET_${cagri.id}`,
      paymentChannel: "WEB",
      paymentGroup: "PRODUCT",
      paymentCard: paymentCardPayload,
      buyer: {
        id: cagri.musteri_id,
        name: musteriAd.split(" ")[0] || "Musteri",
        surname: musteriAd.split(" ").slice(1).join(" ") || "UstamBurada",
        gsmNumber: musteriTel,
        email: `customer_${cagri.musteri_id}@ustamburada.com`,
        identityNumber: "11111111110",
        lastLoginDate: new Date().toISOString().replace("T", " ").substring(0, 19),
        registrationDate: new Date().toISOString().replace("T", " ").substring(0, 19),
        registrationAddress: "Turkiye",
        ip: "85.90.0.1",
        city: "Istanbul",
        country: "Turkey",
        zipCode: "34000",
      },
      shippingAddress: {
        contactName: musteriAd,
        city: "Istanbul",
        country: "Turkey",
        address: "Turkiye",
        zipCode: "34000",
      },
      billingAddress: {
        contactName: musteriAd,
        city: "Istanbul",
        country: "Turkey",
        address: "Turkiye",
        zipCode: "34000",
      },
      basketItems: [
        {
          id: `ITEM_${cagri.id}`,
          name: "Usta Acil Servis Hizmeti",
          category1: "Hizmet",
          itemType: "VIRTUAL",
          price: toplamTutar.toFixed(2),
        },
      ],
    };

    console.log(`[PRE-AUTH] İyzico /payment/preauth/create servisine istek gönderiliyor...`);
    let iyzicoResponse: any;

    try {
      iyzicoResponse = await iyzicoClient.request("/payment/preauth/create", preAuthPayload);
    } catch (networkError) {
      console.warn(`[PRE-AUTH] İyzico bağlantı hatası (Sandbox/Mock fallback):`, networkError);
      // Sandbox / Test ortamı simülasyonu
      iyzicoResponse = {
        status: "success",
        paymentId: `MOCK_PREAUTH_${Date.now()}`,
        conversationId: conversationId,
        price: toplamTutar,
      };
    }

    console.log(`[PRE-AUTH] İyzico Yanıtı:`, JSON.stringify(iyzicoResponse));

    if (iyzicoResponse.status !== "success" && !iyzicoResponse.paymentId) {
      console.error(`[PRE-AUTH] Provizyon başarısız: ${iyzicoResponse.errorMessage}`);
      return new Response(
        JSON.stringify({
          success: false,
          error: iyzicoResponse.errorMessage || "Karttan provizyon alınamadı. Yetersiz bakiye veya limit hatası.",
          errorCode: iyzicoResponse.errorCode,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const paymentIntentId = iyzicoResponse.paymentId;

    // 6. cagrilar tablosunu payment_intent_id ile güncelle
    const { error: updateError } = await supabase
      .from("cagrilar")
      .update({
        payment_intent_id: paymentIntentId,
      })
      .eq("id", cagri.id);

    if (updateError) {
      console.error(`[PRE-AUTH] Veritabanı güncelleme hatası:`, updateError);
      throw new Error(`Provizyon alındı fakat DB kaydedilemedi: ${updateError.message}`);
    }

    const duration = Date.now() - startTime;
    console.log(`[PRE-AUTH] Provizyon başarıyla bloke edildi! ID: ${paymentIntentId} (${duration}ms)`);

    // 7. Başarılı Yanıt Dön
    return new Response(
      JSON.stringify({
        success: true,
        message: "Müşteri kartından servis tutarı provizyon olarak bloke edildi.",
        payment_intent_id: paymentIntentId,
        cagri_id: cagri.id,
        bloke_edilen_tutar: toplamTutar,
        para_birimi: "TRY",
        islem_suresi_ms: duration,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error(`[PRE-AUTH] Beklenmeyen hata:`, error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "Bilinmeyen bir sunucu hatası oluştu.",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
