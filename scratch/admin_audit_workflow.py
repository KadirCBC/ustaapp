import os
import re

log("Scanning Admin Dashboard architecture...")

workspace = WORKSPACES[0]
admin_file = os.path.join(workspace, "lib", "features", "admin", "views", "admin_dashboard_screen.dart")

with open(admin_file, "r", encoding="utf-8", errors="ignore") as f:
    code = f.read()
    lines = code.splitlines()

phase("1. Kod Boyutu ve Yapısal İnceleme")
log(f"Admin paneli toplam satır sayısı: {len(lines)}")
log(f"Admin paneli dosya boyutu: {len(code) / 1024:.1f} KB")

# Tab analizi
menu_items = re.findall(r"title:\s*['\"]([^'\"]+)['\"]", code)
log(f"Tespit edilen menü öğeleri / etiketler: {len(menu_items)}")

# Ağır işlemler ve setState araması
set_states = len(re.findall(r"setState\(", code))
log(f"Toplam setState çağrısı sayısı: {set_states} (Monolitik state yönetimi)")

phase("2. Eksik ve Geliştirilebilir Modüller Taraması")
features = {
    "Reklam / Banner Yönetimi": bool(re.search(r"reklam|banner|sponsor", code, re.I)),
    "Kupon / Promosyon Kodu": bool(re.search(r"kupon|promo|indirim_kodu", code, re.I)),
    "Müşteri Şikayet / Uyuşmazlık (Dispute)": bool(re.search(r"sikayet|dispute|itiraz", code, re.I)),
    "Canlı Destek / Destek Masası": bool(re.search(r"destek|ticket|canli_yardim", code, re.I)),
    "Dinamik SMS / Push Şablonları": bool(re.search(r"sms_template|sablon|sms_sablon", code, re.I)),
    "Usta Rozet ve Seviye Sistemi (Level/Tier)": bool(re.search(r"rozet|seviye|tier|vip_usta", code, re.I)),
    "Sistem Bakım Modu (Maintenance Mode)": bool(re.search(r"bakim_modu|maintenance", code, re.I)),
    "Çoklu Admin Yetkilendirme (RBAC)": bool(re.search(r"super_admin|yetki|sub_admin", code, re.I)),
    "Dışa Aktarma (Excel/CSV Export)": bool(re.search(r"export|csv|excel", code, re.I)),
    "Log / Güvenlik Denetim İzi (Audit Log)": bool(re.search(r"audit_log|denetim_izi", code, re.I)),
}

for feat, exists in features.items():
    log(f" - {feat}: {'MEVCUT' if exists else 'YOK / GELİŞTİRİLEBİLİR'}")

phase("3. Potansiyel Hata ve Risk Analizi")
# Hardcoded IP ve websocket bağlantıları
ws_matches = re.findall(r"ws://[^\s'\"]+", code)
http_matches = re.findall(r"http://[^\s'\"]+", code)
log(f"Hardcoded WS bağlantıları: {set(ws_matches)}")
log(f"Hardcoded HTTP bağlantıları: {set(http_matches)}")

# Hata yakalama oranları
try_count = len(re.findall(r"\btry\s*\{", code))
catch_empty = len(re.findall(r"catch\s*\([^\)]*\)\s*\{\s*\}", code))
log(f"Toplam try-catch: {try_count}, Boş yutulan (silent catch) hata bloğu: {catch_empty}")

print("ADMIN_AUDIT_COMPLETE")
