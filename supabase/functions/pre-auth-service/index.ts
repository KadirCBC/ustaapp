import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { corsHeaders } from "../_shared/cors.ts";
import {
  getClientIp,
  IyzicoApiError,
  IyzicoClient,
  type IyzicoPaymentResponse,
} from "../_shared/iyzico.ts";
import { EdgeLogger } from "../_shared/logger.ts";

interface PreAuthRequest {
  cagri_id?: string;
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

interface CagriPreAuthRow {
  id: string;
  musteri_id: string;
  usta_id: string | null;
  toplam_tutar: number | string | null;
  usta_hakedis: number | string | null;
  komisyon_tutari: number | string | null;
  adres_tarifi: string | null;
  durum: string;
  payment_intent_id: string | null;
  musteri: { full_name?: string | null; phone?: string | null } | null;
  usta: { sub_merchant_id?: string | null } | null;
}

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function formatIyzicoDate(date: Date): string {
  return date.toISOString().replace("T", " ").substring(0, 19);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { success: false, error: "Yalnızca POST istekleri kabul edilir." },
      405,
    );
  }

  const startTime = Date.now();
  const logger = new EdgeLogger("pre-auth-service");
  logger.info("request_received", "Ön otorizasyon (Pre-Auth) isteği alındı.");

  try {
    // 1. Ortam Değişkenlerini Doğrula
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const iyzicoApiKey =
      Deno.env.get("IYZICO_API_KEY") || "sandbox-sample-api-key";
    const iyzicoSecretKey =
      Deno.env.get("IYZICO_SECRET_KEY") || "sandbox-sample-secret-key";
    const iyzicoBaseUrl =
      Deno.env.get("IYZICO_BASE_URL") || "https://sandbox-api.iyzipay.com";
    const allowMockFallback = Deno.env.get("IYZICO_ALLOW_MOCK") === "true";

    if (!supabaseUrl || !supabaseServiceKey) {
      logger.error("env_check", "Supabase ortam değişkenleri eksik.");
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Sunucu yapılandırma hatası: Supabase anahtarları eksik.",
        },
        500,
      );
    }

    // 2. İstek Gövdesini Güvenli Ayrıştır & Doğrula
    let body: PreAuthRequest;
    try {
      body = (await req.json()) as PreAuthRequest;
    } catch {
      logger.warn("parse_body", "Geçersiz JSON gövdesi.");
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Geçersiz JSON istek gövdesi.",
        },
        400,
      );
    }

    const cagriId = body.cagri_id?.trim();
    const cardToken = body.card_token?.trim();
    const cardUserKey = body.card_user_key?.trim();
    const paymentCard = body.payment_card;

    if (!cagriId || !UUID_REGEX.test(cagriId)) {
      logger.warn("validate_input", "Geçersiz veya eksik cagri_id.", { cagriId });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Geçerli bir cagri_id (UUID) zorunludur.",
        },
        400,
      );
    }
    logger.setCagriId(cagriId);

    const iyzicoClient = new IyzicoClient({
      apiKey: iyzicoApiKey,
      secretKey: iyzicoSecretKey,
      baseUrl: iyzicoBaseUrl,
      allowMockFallback,
    });

    if (!cardToken && !paymentCard && !iyzicoClient.isMockMode) {
      logger.warn("validate_card", "Canlı modda card_token veya kart bilgisi eksik.");
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Kart doğrulama bilgisi (card_token) zorunludur.",
        },
        400,
      );
    }

    // 3. Supabase Admin İstemcisini Oluştur (Service Role)
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // 4. cagrilar tablosundan çağrı, müşteri ve alt üye işyeri (usta) bilgilerini çek
    logger.info("fetch_cagri", "Çağrı kaydı veritabanından sorgulanıyor.");
    const { data: cagriRaw, error: cagriError } = await supabase
      .from("cagrilar")
      .select(`
        id,
        musteri_id,
        usta_id,
        toplam_tutar,
        usta_hakedis,
        komisyon_tutari,
        adres_tarifi,
        durum,
        payment_intent_id,
        musteri:profiles!cagrilar_musteri_id_fkey(full_name, phone),
        usta:ustalar!cagrilar_usta_id_fkey(sub_merchant_id)
      `)
      .eq("id", cagriId)
      .single();

    if (cagriError || !cagriRaw) {
      logger.error("fetch_cagri", "Çağrı bulunamadı.", cagriError);
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Belirtilen çağrı kaydı bulunamadı.",
        },
        404,
      );
    }

    const cagri = cagriRaw as unknown as CagriPreAuthRow;

    // İptal veya tamamlanmış çağrıya provizyon açılamaz
    if (cagri.durum === "iptal" || cagri.durum === "tamamlandi") {
      logger.warn("validate_state", "Çağrı durumu provizyon için uygun değil.", {
        durum: cagri.durum,
      });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: `Bu çağrı '${cagri.durum}' durumunda olduğu için provizyon alınamaz.`,
        },
        409,
      );
    }

    const toplamTutar = Number(cagri.toplam_tutar);
    const ustaHakedis =
      cagri.usta_hakedis != null ? Number(cagri.usta_hakedis) : toplamTutar;

    if (!Number.isFinite(toplamTutar) || toplamTutar <= 0) {
      logger.error("validate_amount", "Geçersiz toplam_tutar değeri.", {
        toplam_tutar: cagri.toplam_tutar,
      });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: `Geçersiz çağrı tutarı: ${cagri.toplam_tutar}`,
        },
        422,
      );
    }

    // İdempotency kontrolü: zaten provizyon alınmışsa mevcut payment_intent_id dön
    if (cagri.payment_intent_id) {
      logger.info("idempotent_hit", "Çağrı için mevcut provizyon bulundu.", {
        paymentIntentId: cagri.payment_intent_id,
      });
      return jsonResponse(
        {
          success: true,
          request_id: logger.requestId,
          message: "Bu çağrı için provizyon zaten bloke edilmiş durumda.",
          payment_intent_id: cagri.payment_intent_id,
          cagri_id: cagri.id,
          bloke_edilen_tutar: toplamTutar,
          para_birimi: "TRY",
        },
        200,
      );
    }

    // 5. İyzico Pazaryeri Pre-Auth Payload Hazırla (Tahsilat Değil, Ön Bloke!)
    const conversationId = `preauth_${cagri.id}_${Date.now()}`;
    const musteriAd = (cagri.musteri?.full_name || "UstamBurada Musteri").trim();
    const adParcalari = musteriAd.split(/\s+/);
    const name = adParcalari[0] || "Musteri";
    const surname = adParcalari.slice(1).join(" ") || "UstamBurada";
    const musteriTel = cagri.musteri?.phone || "+905000000000";
    const clientIp = getClientIp(req);
    const adres = cagri.adres_tarifi?.trim() || "Istanbul, Turkiye";
    const subMerchantKey = cagri.usta?.sub_merchant_id?.trim() || undefined;

    let paymentCardPayload: Record<string, unknown>;
    if (cardToken && cardUserKey) {
      paymentCardPayload = {
        cardToken,
        cardUserKey,
      };
    } else if (cardToken) {
      paymentCardPayload = {
        cardToken,
      };
    } else if (paymentCard) {
      paymentCardPayload = {
        cardHolderName: paymentCard.cardHolderName,
        cardNumber: paymentCard.cardNumber,
        expireMonth: paymentCard.expireMonth,
        expireYear: paymentCard.expireYear,
        cvc: paymentCard.cvc,
        registerCard: 0,
      };
    } else {
      paymentCardPayload = {
        cardToken: "sandbox_card_token_default",
      };
    }

    const basketItem: Record<string, unknown> = {
      id: `ITEM_${cagri.id}`,
      name: "UstamBurada Acil Servis Hizmeti",
      category1: "Ev Hizmetleri",
      itemType: "VIRTUAL",
      price: toplamTutar.toFixed(2),
    };

    // Pazaryeri modelinde alt üye işyeri anahtarı varsa preauth sepet kalemine işlenir
    if (subMerchantKey) {
      basketItem.subMerchantKey = subMerchantKey;
      basketItem.subMerchantPrice = Math.min(ustaHakedis, toplamTutar).toFixed(2);
    }

    const nowFormatted = formatIyzicoDate(new Date());
    const preAuthPayload: Record<string, unknown> = {
      locale: "tr",
      conversationId,
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
        name,
        surname,
        gsmNumber: musteriTel,
        email: `customer_${cagri.musteri_id}@ustamburada.com`,
        identityNumber: "11111111110",
        lastLoginDate: nowFormatted,
        registrationDate: nowFormatted,
        registrationAddress: adres,
        ip: clientIp,
        city: "Istanbul",
        country: "Turkey",
        zipCode: "34000",
      },
      shippingAddress: {
        contactName: musteriAd,
        city: "Istanbul",
        country: "Turkey",
        address: adres,
        zipCode: "34000",
      },
      billingAddress: {
        contactName: musteriAd,
        city: "Istanbul",
        country: "Turkey",
        address: adres,
        zipCode: "34000",
      },
      basketItems: [basketItem],
    };

    logger.info("iyzico_preauth_call", "İyzico /payment/preauth çağrısı başlatılıyor.", {
      conversationId,
      blokeEdilecekTutar: toplamTutar.toFixed(2),
      hasSubMerchant: Boolean(subMerchantKey),
      mockMode: iyzicoClient.isMockMode,
    });

    let iyzicoResponse: IyzicoPaymentResponse;
    try {
      iyzicoResponse = await iyzicoClient.createPreAuth(preAuthPayload);
    } catch (iyzicoErr) {
      if (!iyzicoClient.isMockMode) {
        logger.error("iyzico_preauth_failed", "İyzico Pre-Auth canlı API hatası.", iyzicoErr);
        const status = iyzicoErr instanceof IyzicoApiError ? iyzicoErr.statusCode : 502;
        const message = iyzicoErr instanceof Error ? iyzicoErr.message : "Ödeme ağ geçidi hatası.";
        const errorCode = iyzicoErr instanceof IyzicoApiError ? iyzicoErr.errorCode : "GATEWAY_ERROR";
        return jsonResponse(
          {
            success: false,
            request_id: logger.requestId,
            error: message,
            errorCode,
          },
          status,
        );
      }

      logger.warn(
        "iyzico_preauth_mock",
        "Sandbox/Mock modunda İyzico Pre-Auth simülasyonu uygulanıyor.",
        iyzicoErr,
      );
      iyzicoResponse = {
        status: "success",
        paymentId: `SANDBOX_PREAUTH_${Date.now()}`,
        conversationId,
        price: toplamTutar,
      };
    }

    if (iyzicoResponse.status !== "success" || !iyzicoResponse.paymentId) {
      logger.error("iyzico_preauth_rejected", "İyzico provizyonu reddetti.", {
        status: iyzicoResponse.status,
        errorCode: iyzicoResponse.errorCode,
        errorMessage: iyzicoResponse.errorMessage,
      });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error:
            iyzicoResponse.errorMessage ||
            "Karttan provizyon alınamadı. Bakiye veya kart limitini kontrol edin.",
          errorCode: iyzicoResponse.errorCode,
        },
        400,
      );
    }

    const paymentIntentId = String(iyzicoResponse.paymentId);

    // 6. cagrilar tablosuna payment_intent_id kaydet ve çağrıyı doğrula
    logger.info("db_update_preauth", "payment_intent_id veritabanına yazılıyor.", {
      paymentIntentId,
    });

    const { data: updatedRow, error: updateError } = await supabase
      .from("cagrilar")
      .update({ payment_intent_id: paymentIntentId })
      .eq("id", cagri.id)
      .is("payment_intent_id", null)
      .select("id, payment_intent_id, durum, toplam_tutar")
      .single();

    if (updateError || !updatedRow || updatedRow.payment_intent_id !== paymentIntentId) {
      logger.error(
        "db_verify_preauth",
        "Provizyon alındı ancak çağrı kaydı doğrulanamadı.",
        updateError,
      );
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: `Provizyon bloke edildi (${paymentIntentId}) ancak veritabanı doğrulanamadı.`,
        },
        500,
      );
    }

    const durationMs = Date.now() - startTime;
    logger.info("preauth_completed", "Ön otorizasyon bloke edildi ve doğrulandı.", {
      paymentIntentId,
      blokeEdilenTutar: toplamTutar,
      durationMs,
    });

    // 7. Başarılı Yanıt Dön
    return jsonResponse(
      {
        success: true,
        request_id: logger.requestId,
        message: "Müşteri kartından servis tutarı ön otorizasyon (provizyon) olarak bloke edildi.",
        payment_intent_id: paymentIntentId,
        conversation_id: conversationId,
        cagri_id: updatedRow.id,
        durum: updatedRow.durum,
        bloke_edilen_tutar: toplamTutar,
        para_birimi: "TRY",
        verified: true,
        islem_suresi_ms: durationMs,
      },
      200,
    );
  } catch (error: unknown) {
    const durationMs = Date.now() - startTime;
    logger.error("unhandled_exception", "Beklenmeyen Pre-Auth hatası.", {
      error,
      durationMs,
    });
    const message =
      error instanceof Error ? error.message : "Bilinmeyen bir sunucu hatası oluştu.";
    return jsonResponse(
      {
        success: false,
        request_id: logger.requestId,
        error: message,
      },
      500,
    );
  }
});
