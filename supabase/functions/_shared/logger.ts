// Yapılandırılmış JSON Loglama Yardımcı Modülü (Supabase Edge Functions)

export type LogLevel = "INFO" | "WARN" | "ERROR";

const SENSITIVE_KEYS = new Set([
  "cardnumber",
  "cvc",
  "cardtoken",
  "secretkey",
  "apikey",
  "authorization",
  "service_role_key",
]);

function sanitizeMeta(value: unknown, depth = 0): unknown {
  if (depth > 4 || value === null || value === undefined) return value;
  if (value instanceof Error) {
    return {
      name: value.name,
      message: value.message,
      stack: value.stack?.split("\n").slice(0, 4).join(" | "),
    };
  }
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeMeta(item, depth + 1));
  }
  if (typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (SENSITIVE_KEYS.has(k.toLowerCase())) {
        out[k] = "***REDACTED***";
      } else {
        out[k] = sanitizeMeta(v, depth + 1);
      }
    }
    return out;
  }
  return value;
}

export class EdgeLogger {
  private readonly service: string;
  readonly requestId: string;
  private cagriId?: string;

  constructor(service: string, requestId?: string) {
    this.service = service;
    this.requestId = requestId ?? crypto.randomUUID();
  }

  setCagriId(cagriId: string): void {
    this.cagriId = cagriId;
  }

  private emit(level: LogLevel, step: string, message: string, meta?: unknown): void {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      service: this.service,
      requestId: this.requestId,
      ...(this.cagriId ? { cagriId: this.cagriId } : {}),
      step,
      message,
      ...(meta !== undefined ? { meta: sanitizeMeta(meta) } : {}),
    };

    const line = JSON.stringify(entry);
    if (level === "ERROR") {
      console.error(line);
    } else if (level === "WARN") {
      console.warn(line);
    } else {
      console.log(line);
    }
  }

  info(step: string, message: string, meta?: unknown): void {
    this.emit("INFO", step, message, meta);
  }

  warn(step: string, message: string, meta?: unknown): void {
    this.emit("WARN", step, message, meta);
  }

  error(step: string, message: string, meta?: unknown): void {
    this.emit("ERROR", step, message, meta);
  }
}
