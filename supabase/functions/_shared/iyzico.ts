// İyzico Pazaryeri & Pre-Auth API Yardımcı Modülü (Deno / TypeScript)
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

export interface IyzicoConfig {
  apiKey: string;
  secretKey: string;
  baseUrl: string; // https://sandbox-api.iyzipay.com veya https://api.iyzipay.com
}

export class IyzicoClient {
  private apiKey: string;
  private secretKey: string;
  private baseUrl: string;

  constructor(config: IyzicoConfig) {
    this.apiKey = config.apiKey;
    this.secretKey = config.secretKey;
    this.baseUrl = config.baseUrl.replace(/\/$/, "");
  }

  /**
   * İyzico V2 HMAC-SHA256 Yetkilendirme Başlığı Üretimi
   * Format: IYZWSv2 <apiKey>:<signature>
   */
  private async generateV2AuthHeader(uriPath: string, randomKey: string, payloadJson: string): Promise<string> {
    const dataToSign = `${randomKey}${uriPath}${payloadJson}`;
    const encoder = new TextEncoder();
    const keyData = encoder.encode(this.secretKey);

    const cryptoKey = await crypto.subtle.importKey(
      "raw",
      keyData,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const signatureBuffer = await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      encoder.encode(dataToSign)
    );

    const signatureBase64 = encodeBase64(signatureBuffer);
    return `IYZWSv2 ${this.apiKey}:${signatureBase64}`;
  }

  /**
   * İyzico API HTTP POST İsteği
   */
  async request<T = any>(endpoint: string, payload: Record<string, any>): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    const randomKey = Date.now().toString() + Math.random().toString(36).substring(2, 8);
    const bodyString = JSON.stringify(payload);

    const authHeader = await this.generateV2AuthHeader(endpoint, randomKey, bodyString);

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": authHeader,
        "x-iyzi-rnd": randomKey,
        "x-iyzi-client-version": "iyzipay-node-2.0.48",
      },
      body: bodyString,
    });

    const data = await response.json();
    return data as T;
  }
}
