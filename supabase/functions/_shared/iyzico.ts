// İyzico Pazaryeri & Pre-Auth API v2 İstemcisi (Deno / TypeScript)
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

export interface IyzicoConfig {
  apiKey: string;
  secretKey: string;
  baseUrl: string; // https://sandbox-api.iyzipay.com veya https://api.iyzipay.com
  allowMockFallback?: boolean;
  timeoutMs?: number;
}

export interface IyzicoItemTransaction {
  itemId?: string;
  paymentTransactionId?: string;
  transactionStatus?: number;
  price?: number;
  paidPrice?: number;
  merchantCommissionRate?: number;
  merchantCommissionRateAmount?: number;
  subMerchantKey?: string;
  subMerchantPrice?: number;
  subMerchantPayoutRate?: number;
  subMerchantPayoutAmount?: number;
  merchantPayoutAmount?: number;
}

export interface IyzicoBaseResponse {
  status: "success" | "failure" | string;
  locale?: string;
  systemTime?: number;
  conversationId?: string;
  errorCode?: string;
  errorMessage?: string;
  errorGroup?: string;
}

export interface IyzicoPaymentResponse extends IyzicoBaseResponse {
  paymentId?: string;
  price?: number;
  paidPrice?: number;
  currency?: string;
  fraudStatus?: number;
  paymentStatus?: string;
  itemTransactions?: IyzicoItemTransaction[];
}

export class IyzicoApiError extends Error {
  readonly statusCode: number;
  readonly errorCode?: string;
  readonly responseBody?: unknown;

  constructor(
    message: string,
    statusCode = 502,
    errorCode?: string,
    responseBody?: unknown,
  ) {
    super(message);
    this.name = "IyzicoApiError";
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.responseBody = responseBody;
  }
}

export class IyzicoClient {
  private readonly apiKey: string;
  private readonly secretKey: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  readonly isMockMode: boolean;

  constructor(config: IyzicoConfig) {
    this.apiKey = config.apiKey;
    this.secretKey = config.secretKey;
    this.baseUrl = config.baseUrl.replace(/\/$/, "");
    this.timeoutMs = config.timeoutMs ?? 15000;
    this.isMockMode =
      Boolean(config.allowMockFallback) ||
      this.apiKey === "sandbox-sample-api-key" ||
      this.secretKey === "sandbox-sample-secret-key";
  }

  /**
   * İyzico V2 HMAC-SHA256 Yetkilendirme Başlığı Üretimi
   * Spec:
   *   1. signature = HMAC-SHA256_HEX(randomKey + uriPath + bodyString, secretKey)
   *   2. authString = "apiKey:" + apiKey + "&randomKey:" + randomKey + "&signature:" + signature
   *   3. Header = "IYZWSv2 " + Base64(authString)
   */
  private async generateV2AuthHeader(
    uriPath: string,
    randomKey: string,
    payloadJson: string,
  ): Promise<string> {
    const dataToSign = `${randomKey}${uriPath}${payloadJson}`;
    const encoder = new TextEncoder();

    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      encoder.encode(this.secretKey),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const signatureBuffer = await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      encoder.encode(dataToSign),
    );

    const signatureHex = Array.from(new Uint8Array(signatureBuffer))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");

    const plainAuthString =
      `apiKey:${this.apiKey}&randomKey:${randomKey}&signature:${signatureHex}`;
    const encodedAuth = encodeBase64(encoder.encode(plainAuthString));
    return `IYZWSv2 ${encodedAuth}`;
  }

  /**
   * İyzico REST API POST İsteği (Zaman aşımı + HTTP/JSON hata yönetimi dahil)
   */
  async request<T extends IyzicoBaseResponse = IyzicoPaymentResponse>(
    uriPath: string,
    payload: Record<string, unknown>,
  ): Promise<T> {
    const normalizedPath = uriPath.startsWith("/") ? uriPath : `/${uriPath}`;
    const url = `${this.baseUrl}${normalizedPath}`;
    const randomKey =
      `${Date.now()}${Math.floor(100000 + Math.random() * 900000)}`;
    const bodyString = JSON.stringify(payload);
    const authHeader = await this.generateV2AuthHeader(
      normalizedPath,
      randomKey,
      bodyString,
    );

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": authHeader,
          "x-iyzi-rnd": randomKey,
          "x-iyzi-client-version": "iyzipay-deno-2.0.0",
        },
        body: bodyString,
        signal: controller.signal,
      });

      const rawText = await response.text();
      let parsed: Record<string, unknown>;
      try {
        parsed = rawText ? JSON.parse(rawText) : {};
      } catch {
        throw new IyzicoApiError(
          `İyzico geçersiz JSON yanıtı döndü (HTTP ${response.status}).`,
          502,
          "INVALID_JSON_RESPONSE",
          rawText.slice(0, 300),
        );
      }

      if (!response.ok) {
        const msg =
          typeof parsed.errorMessage === "string"
            ? parsed.errorMessage
            : `İyzico HTTP hatası: ${response.status}`;
        const code =
          typeof parsed.errorCode === "string" ? parsed.errorCode : undefined;
        throw new IyzicoApiError(msg, response.status, code, parsed);
      }

      return parsed as unknown as T;
    } catch (error) {
      if (error instanceof IyzicoApiError) throw error;
      if (error instanceof DOMException && error.name === "AbortError") {
        throw new IyzicoApiError(
          `İyzico API zaman aşımı (${this.timeoutMs}ms).`,
          504,
          "IYZICO_TIMEOUT",
        );
      }
      const message = error instanceof Error ? error.message : String(error);
      throw new IyzicoApiError(
        `İyzico API bağlantı hatası: ${message}`,
        502,
        "IYZICO_NETWORK_ERROR",
      );
    } finally {
      clearTimeout(timer);
    }
  }

  /** Ön Otorizasyon (Pre-Auth) Oluşturma: POST /payment/preauth */
  createPreAuth(payload: Record<string, unknown>): Promise<IyzicoPaymentResponse> {
    return this.request<IyzicoPaymentResponse>("/payment/preauth", payload);
  }

  /** Ön Otorizasyon Kapama / Kesin Tahsilat (Capture / Post-Auth): POST /payment/postauth */
  capturePostAuth(payload: Record<string, unknown>): Promise<IyzicoPaymentResponse> {
    return this.request<IyzicoPaymentResponse>("/payment/postauth", payload);
  }

  /** Provizyon İptali / Blokaj Kaldırma (Reverse-Auth / Cancel): POST /payment/cancel */
  cancelPayment(payload: Record<string, unknown>): Promise<IyzicoPaymentResponse> {
    return this.request<IyzicoPaymentResponse>("/payment/cancel", payload);
  }

  /** Pazaryeri Alt Üye İşyeri Kalemi Onayı (Escrow Payout Release): POST /payment/iyzipos/item/approve */
  approveMarketplaceItem(payload: {
    locale: string;
    conversationId: string;
    paymentTransactionId: string;
  }): Promise<IyzicoBaseResponse> {
    return this.request<IyzicoBaseResponse>(
      "/payment/iyzipos/item/approve",
      payload,
    );
  }
}

export function getClientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim();
    if (first) return first;
  }
  return req.headers.get("cf-connecting-ip")?.trim() || "85.90.0.1";
}
