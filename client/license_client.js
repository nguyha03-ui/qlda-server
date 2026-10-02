// QLDA Work Manager - kiểm tra license + cập nhật (bản Web / React, chạy trên trình duyệt)
const BASE = "https://nguyha03-ui.github.io/qlda-server";
const CACHE_KEY = "qlda_license_cache";
const OFFLINE_GRACE_DAYS = 7;

// Băm giống hệt gen_license.py: SHA-256("mãKH:KEY", KEY viết hoa, bỏ khoảng trắng)
export async function licenseHash(customerCode, licenseKey) {
  const raw = `${customerCode.trim()}:${licenseKey.trim().toUpperCase()}`;
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(raw));
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join("");
}

async function fetchJson(file) {
  // ?t= để tránh bộ nhớ đệm của GitHub Pages / trình duyệt
  const r = await fetch(`${BASE}/${file}?t=${Date.now()}`, { cache: "no-store" });
  if (!r.ok) throw new Error(`${file}: HTTP ${r.status}`);
  return r.json();
}

function readCache() { try { return JSON.parse(localStorage.getItem(CACHE_KEY)); } catch { return null; } }
function writeCache(v) { try { localStorage.setItem(CACHE_KEY, JSON.stringify(v)); } catch {} }

function judge(entry, today = new Date()) {
  if (!entry) return { ok: false, code: "unknown", message: "Mã khách hàng hoặc license key không đúng." };
  if (entry.status === "blocked") return { ok: false, code: "blocked", message: "License đã bị khóa. Liên hệ Mr Hà: 0916269395." };
  if (entry.status === "unpaid") return { ok: false, code: "unpaid", message: "License chưa được thanh toán." };
  if (entry.expires && new Date(entry.expires + "T23:59:59") < today)
    return { ok: false, code: "expired", message: `License đã hết hạn ngày ${entry.expires}.` };
  return { ok: true, code: "active", message: entry.expires ? `Còn hạn đến ${entry.expires}` : "License vĩnh viễn", plan: entry.plan, expires: entry.expires };
}

/** Trả về { ok, code, message, offline? }. Gọi khi mở ứng dụng và định kỳ (vd. mỗi 6 giờ). */
export async function checkLicense(customerCode, licenseKey) {
  const h = await licenseHash(customerCode, licenseKey);
  try {
    const db = await fetchJson("license-status.json");
    const result = judge(db.licenses?.[h]);
    if (result.code !== "unknown") writeCache({ h, entry: db.licenses[h], at: Date.now() });
    return result;
  } catch (e) {
    // Mất mạng: dùng bản lưu gần nhất trong OFFLINE_GRACE_DAYS ngày
    const c = readCache();
    if (c && c.h === h && Date.now() - c.at < OFFLINE_GRACE_DAYS * 864e5)
      return { ...judge(c.entry), offline: true };
    return { ok: false, code: "offline", message: "Không kết nối được máy chủ license. Hãy kiểm tra mạng." };
  }
}

/** So sánh phiên bản dạng 1.2.3. Trả về { hasUpdate, forced, latest, url, notes } */
export async function checkUpdate(currentVersion) {
  const v = await fetchJson("version.json");
  const cmp = (a, b) => {
    const x = a.split(".").map(Number), y = b.split(".").map(Number);
    for (let i = 0; i < 3; i++) { if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) - (y[i] || 0); }
    return 0;
  };
  return {
    hasUpdate: cmp(currentVersion, v.latest_version) < 0,
    forced: cmp(currentVersion, v.min_supported_version) < 0, // bản quá cũ → bắt buộc cập nhật
    latest: v.latest_version, url: v.download_url, notes: v.release_notes,
  };
}
