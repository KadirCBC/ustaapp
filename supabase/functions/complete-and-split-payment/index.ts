import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { corsHeaders } from "../_shared/cors.ts";
import {
  getClientIp,
  IyzicoApiError,
  IyzicoClient,
  type IyzicoPaymentResponse,
} from "../_shared/iyzico.ts";
import { EdgeLogger } from "../_shared/logger.ts";

interface SplitPaymentRequest {
  cagri_id?: string;
  action?: "capture" | "reverse"; // varsayılan: 'capture'
  reason?: string;
}

interface CagriSplitRow {
  id: string;
  durum: string;
  payment_intent_id: string | null;
  usta_hakedis: number | string | null;
  komisyon_tutari: number | string | null;
  toplam_tutar: number | string | null;
  usta_id: string | null;
  usta: {
    id: string;
    sub_merchant_id: string | null;
    servis_ucreti: number | string | null;
  } | null;
}

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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
  const logger = new EdgeLogger("complete-and-split-payment");
  logger.info("request_received", "Tahsilat ve Pazaryeri Hakediş Dağıtımı isteği alındı.");

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
    const autoApproveItems = Deno.env.get("IYZICO_AUTO_APPROVE_ITEMS") !== "false";

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

    // 2. İstek Gövdesini Güvenli Ayrıştır
    let body: SplitPaymentRequest;
    try {
      body = (await req.json()) as SplitPaymentRequest;
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
    const action = body.action ?? "capture";
    const reason = body.reason?.trim();

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

    if (action !== "capture" && action !== "reverse") {
      logger.warn("validate_action", "Geçersiz action parametresi.", { action });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Geçersiz action değeri. 'capture' veya 'reverse' olmalıdır.",
        },
        400,
      );
    }

    // 3. Supabase Admin İstemcisi
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // 4. cagrilar ve usta (alt üye işyeri) kayıtlarını çek
    logger.info("fetch_cagri", "Çağrı ve alt üye işyeri bilgileri çekiliyor.", { action });
    const { data: cagriRaw, error: cagriError } = await supabase
      .from("cagrilar")
      .select(`
        id,
        durum,
        payment_intent_id,
        usta_hakedis,
        komisyon_tutari,
        toplam_tutar,
        usta_id,
        usta:ustalar!cagrilar_usta_id_fkey(id, sub_merchant_id, servis_ucreti)
      `)
      .eq("id", cagriId)
      .single();

    if (cagriError || !cagriRaw) {
      logger.error("fetch_cagri", "Çağrı kaydı bulunamadı.", cagriError);
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Çağrı kaydı bulunamadı.",
        },
        404,
      );
    }

    const cagri = cagriRaw as unknown as CagriSplitRow;
    const paymentIntentId = cagri.payment_intent_id?.trim();

    if (!paymentIntentId) {
      logger.warn("validate_preauth", "Çağrıda payment_intent_id yok.");
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Bu çağrı için önceden bloke edilmiş bir provizyon (payment_intent_id) bulunamadı.",
        },
        400,
      );
    }

    const iyzicoClient = new IyzicoClient({
      apiKey: iyzicoApiKey,
      secretKey: iyzicoSecretKey,
      baseUrl: iyzicoBaseUrl,
      allowMockFallback,
    });

    const clientIp = getClientIp(req);
    const conversationId = `split_${cagri.id}_${Date.now()}`;

    // =========================================================================
    // AKIŞ A: ACİL DURUM / İPTAL -> PROVİZYON BLOKAJINI SERBEST BIRAK (REVERSE-AUTH)
    // =========================================================================
    if (action === "reverse" || cagri.durum === "iptal") {
      if (cagri.durum === "tamamlandi") {
        logger.warn("reverse_conflict", "Tamamlanmış çağrı için reverse-auth yapılamaz.");
        return jsonResponse(
          {
            success: false,
            request_id: logger.requestId,
            error: "Kesin tahsilatı tamamlanmış bir çağrıda provizyon iptali yapılamaz; iade (/refund) gerekir.",
          },
          409,
        );
      }

      logger.info("reverse_auth_start", "Provizyon blokajı serbest bırakılıyor (Cancel/Void).", {
        paymentIntentId,
        reason: reason || "Cagri iptal edildi",
      });

      const cancelPayload = {
        locale: "tr",
        conversationId,
        paymentId: paymentIntentId,
        ip: clientIp,
        reason: "BUYER_REQUEST",
        description: reason || "Müşteri/Usta çağrıyı iptal etti veya zaman aşımı",
      };

      let cancelResponse: IyzicoPaymentResponse;
      try {
        cancelResponse = await iyzicoClient.cancelPayment(cancelPayload);
      } catch (cancelErr) {
        if (!iyzicoClient.isMockMode) {
          logger.error("iyzico_cancel_failed", "İyzico Reverse-Auth hatası.", cancelErr);
          const status = cancelErr instanceof IyzicoApiError ? cancelErr.statusCode : 502;
          const message =
            cancelErr instanceof Error ? cancelErr.message : "Provizyon iptal edilemedi.";
          return jsonResponse(
            {
              success: false,
              request_id: logger.requestId,
              error: message,
            },
            status,
          );
        }

        logger.warn("iyzico_cancel_mock", "Sandbox/Mock modunda Reverse-Auth simüle edildi.", cancelErr);
        cancelResponse = {
          status: "success",
          paymentId: paymentIntentId,
          conversationId,
        };
      }

      if (cancelResponse.status !== "success") {
        logger.error("iyzico_cancel_rejected", "İyzico provizyon iptalini reddetti.", {
          errorCode: cancelResponse.errorCode,
          errorMessage: cancelResponse.errorMessage,
        });
        return jsonResponse(
          {
            success: false,
            request_id: logger.requestId,
            error: cancelResponse.errorMessage || "Provizyon serbest bırakılamadı.",
            errorCode: cancelResponse.errorCode,
          },
          400,
        );
      }

      const { error: cancelUpdateErr } = await supabase
        .from("cagrilar")
        .update({ durum: "iptal" })
        .eq("id", cagri.id);

      if (cancelUpdateErr) {
        logger.error("db_update_cancel", "Provizyon iptal edildi fakat DB güncellenemedi.", cancelUpdateErr);
        return jsonResponse(
          {
            success: false,
            request_id: logger.requestId,
            error: `Bloke kaldırıldı ancak veritabanı güncellenemedi: ${cancelUpdateErr.message}`,
          },
          500,
        );
      }

      const durationMs = Date.now() - startTime;
      logger.info("reverse_auth_completed", "Provizyon blokajı başarıyla serbest bırakıldı.", {
        paymentIntentId,
        durationMs,
      });

      return jsonResponse(
        {
          success: true,
          request_id: logger.requestId,
          message: "Kart üzerindeki ön otorizasyon blokajı başarıyla serbest bırakıldı.",
          cagri_id: cagri.id,
          durum: "iptal",
          payment_intent_id: paymentIntentId,
          islem_suresi_ms: durationMs,
        },
        200,
      );
    }

    // =========================================================================
    // AKIŞ B: İŞ BİTİMİ -> KESİN TAHSİLAT (CAPTURE) & PAZARYERİ SPLIT DAĞITIMI
    // =========================================================================
    const toplamTutar = Number(cagri.toplam_tutar);
    const ustaHakedis =
      cagri.usta_hakedis != null
        ? Number(cagri.usta_hakedis)
        : Number(cagri.usta?.servis_ucreti ?? 0);
    const komisyonTutari =
      cagri.komisyon_tutari != null
        ? Number(cagri.komisyon_tutari)
        : Number((toplamTutar - ustaHakedis).toFixed(2));
    const ustaSubMerchantId = cagri.usta?.sub_merchant_id?.trim() || "";

    // İdempotency: zaten tamamlandıysa yeniden tahsilat yapma
    if (cagri.durum === "tamamlandi") {
      logger.info("capture_idempotent", "Çağrı daha önce tamamlanmış; mükerrer capture engellendi.");
      return jsonResponse(
        {
          success: true,
          request_id: logger.requestId,
          message: "Bu çağrı için tahsilat ve hakediş dağıtımı zaten tamamlanmış.",
          cagri_id: cagri.id,
          durum: "tamamlandi",
          payment_id: paymentIntentId,
          finansal_dagilim: {
            toplam_tutar: toplamTutar,
            usta_hakedis: ustaHakedis,
            platform_komisyon: komisyonTutari,
            usta_sub_merchant_id: ustaSubMerchantId || "SANDBOX_SUB_MERCHANT",
          },
        },
        200,
      );
    }

    if (!Number.isFinite(toplamTutar) || toplamTutar <= 0) {
      logger.error("validate_amounts", "Geçersiz toplam_tutar.", { toplam_tutar: cagri.toplam_tutar });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: `Geçersiz toplam tutar: ${cagri.toplam_tutar}`,
        },
        422,
      );
    }

    if (ustaHakedis < 0 || komisyonTutari < 0 || ustaHakedis + komisyonTutari > toplamTutar + 0.05) {
      logger.error("validate_split_math", "Hakediş + komisyon toplamı tutarsız.", {
        toplamTutar,
        ustaHakedis,
        komisyonTutari,
      });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Finansal dağıtım tutarları tutarsız.",
        },
        422,
      );
    }

    if (!ustaSubMerchantId && !iyzicoClient.isMockMode) {
      logger.error("validate_submerchant", "Canlı modda ustanın sub_merchant_id kaydı eksik.", {
        ustaId: cagri.usta_id,
      });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Ustanın Alt Üye İşyeri (sub_merchant_id) tanımlı olmadığı için hakediş aktarılamadı.",
        },
        422,
      );
    }

    const effectiveSubMerchantId = ustaSubMerchantId || "SANDBOX_SUB_MERCHANT_KEY";

    logger.info("capture_split_plan", "Kesin tahsilat & Alt Üye İşyeri dağıtım planı hazır.", {
      paymentIntentId,
      toplamTutar,
      ustaHakedis,
      komisyonTutari,
      subMerchantId: effectiveSubMerchantId,
    });

    // 5. İyzico /payment/postauth ile bloke edilen provizyonu kesin tahsilata çevir
    const postAuthPayload: Record<string, unknown> = {
      locale: "tr",
      conversationId,
      paymentId: paymentIntentId,
      paidPrice: toplamTutar.toFixed(2),
      currency: "TRY",
      ip: clientIp,
    };

    let postAuthResponse: IyzicoPaymentResponse;
    try {
      postAuthResponse = await iyzicoClient.capturePostAuth(postAuthPayload);
    } catch (postAuthErr) {
      if (!iyzicoClient.isMockMode) {
        logger.error("iyzico_postauth_failed", "İyzico Post-Auth (Capture) hatası.", postAuthErr);
        const status = postAuthErr instanceof IyzicoApiError ? postAuthErr.statusCode : 502;
        const message =
          postAuthErr instanceof Error
            ? postAuthErr.message
            : "Kesin tahsilat gerçekleştirilemedi.";
        return jsonResponse(
          {
            success: false,
            request_id: logger.requestId,
            error: message,
          },
          status,
        );
      }

      logger.warn(
        "iyzico_postauth_mock",
        "Sandbox/Mock modunda Post-Auth & Split simüle edildi.",
        postAuthErr,
      );
      postAuthResponse = {
        status: "success",
        paymentId: paymentIntentId,
        price: toplamTutar,
        paidPrice: toplamTutar,
        itemTransactions: [
          {
            itemId: `ITEM_${cagri.id}`,
            paymentTransactionId: `TX_${cagri.id}`,
            subMerchantKey: effectiveSubMerchantId,
            subMerchantPrice: ustaHakedis,
            subMerchantPayoutAmount: ustaHakedis,
            merchantPayoutAmount: komisyonTutari,
          },
        ],
      };
    }

    if (postAuthResponse.status !== "success" || !postAuthResponse.paymentId) {
      logger.error("iyzico_postauth_rejected", "İyzico Post-Auth işlemini reddetti.", {
        errorCode: postAuthResponse.errorCode,
        errorMessage: postAuthResponse.errorMessage,
      });
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error:
            postAuthResponse.errorMessage ||
            "Provizyon kesin tahsilata dönüştürülemedi.",
          errorCode: postAuthResponse.errorCode,
        },
        400,
      );
    }

    // 6. Pazaryeri Alt Üye İşyeri (Sub-Merchant) Hakediş Onayı (Approval)
    const approvedTransactions: string[] = [];
    if (
      autoApproveItems &&
      Array.isArray(postAuthResponse.itemTransactions) &&
      postAuthResponse.itemTransactions.length > 0 &&
      !iyzicoClient.isMockMode
    ) {
      for (const tx of postAuthResponse.itemTransactions) {
        if (!tx.paymentTransactionId) continue;
        try {
          const approveRes = await iyzicoClient.approveMarketplaceItem({
            locale: "tr",
            conversationId,
            paymentTransactionId: tx.paymentTransactionId,
          });
          if (approveRes.status === "success") {
            approvedTransactions.push(tx.paymentTransactionId);
          } else {
            logger.warn("iyzico_item_approve_warn", "Alt üye işlem onayı uyarısı.", {
              paymentTransactionId: tx.paymentTransactionId,
              errorMessage: approveRes.errorMessage,
            });
          }
        } catch (approveErr) {
          logger.warn("iyzico_item_approve_exception", "Item approve adımında istisna.", {
            paymentTransactionId: tx.paymentTransactionId,
            approveErr,
          });
        }
      }
    }

    // 7. Veritabanında Çağrıyı 'tamamlandi' Olarak Güncelle & Doğrula
    const { data: completedRow, error: updateError } = await supabase
      .from("cagrilar")
      .update({ durum: "tamamlandi" })
      .eq("id", cagri.id)
      .select("id, durum")
      .single();

    if (updateError || !completedRow) {
      logger.error(
        "db_update_completed",
        "Tahsilat başarılı oldu ancak çağrı 'tamamlandi' olarak işaretlenemedi.",
        updateError,
      );
      return jsonResponse(
        {
          success: false,
          request_id: logger.requestId,
          error: "Ödeme tahsil edildi fakat sipariş durumu güncellenemedi.",
        },
        500,
      );
    }

    const durationMs = Date.now() - startTime;
    logger.info("capture_and_split_completed", "Tahsilat ve alt üye hakediş dağıtımı tamamlandı.", {
      paymentId: postAuthResponse.paymentId,
      approvedTransactions,
      ustaHakedis,
      komisyonTutari,
      durationMs,
    });

    return jsonResponse(
      {
        success: true,
        request_id: logger.requestId,
        message:
          "Provizyon kesin tahsilata dönüştürüldü; usta hakedişi alt üye hesabına, komisyon şirket hesabına ayrıldı.",
        cagri_id: completedRow.id,
        durum: completedRow.durum,
        payment_id: postAuthResponse.paymentId,
        approved_transaction_ids: approvedTransactions,
        finansal_dagilim: {
          toplam_tutar: toplamTutar,
          usta_hakedis: ustaHakedis,
          platform_komisyon: komisyonTutari,
          usta_sub_merchant_id: effectiveSubMerchantId,
        },
        islem_suresi_ms: durationMs,
      },
      200,
    );
  } catch (error: unknown) {
    const durationMs = Date.now() - startTime;
    logger.error("unhandled_exception", "Beklenmeyen tahsilat/split hatası.", {
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
