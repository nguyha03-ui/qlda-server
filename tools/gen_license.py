#!/usr/bin/env python3
"""Cong cu cho admin: sinh ma khach hang, license key va quan ly license-status.json.

Cach dung:
  python gen_license.py new --plan term --days 365
  python gen_license.py new --plan trial --days 14
  python gen_license.py new --plan perpetual
  python gen_license.py status <MA_KH> <LICENSE_KEY> active|unpaid|blocked
  python gen_license.py extend <MA_KH> <LICENSE_KEY> --days 365
  python gen_license.py list

Luu y: license-status.json nam tren kho CONG KHAI, chi chua ma bam (hash).
Ma khach hang va license key goc gui rieng cho khach, KHONG dua len GitHub.
"""
import argparse, hashlib, json, secrets, string, sys
from datetime import date, timedelta
from pathlib import Path

DB = Path(__file__).resolve().parent.parent / "license-status.json"


def license_hash(customer_code: str, license_key: str) -> str:
    """Phai giong het ham bam trong ung dung: SHA-256 cua 'maKH:KEY' (KEY viet hoa, bo khoang trang)."""
    raw = f"{customer_code.strip()}:{license_key.strip().upper()}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def load():
    if DB.exists():
        return json.loads(DB.read_text(encoding="utf-8"))
    return {"schema": 1, "updated": "", "licenses": {}}


def save(data):
    data["updated"] = date.today().isoformat()
    data["licenses"] = dict(sorted(data["licenses"].items()))
    DB.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def new_customer_code():
    return "".join(secrets.choice(string.digits) for _ in range(8))


def new_key():
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # bo ky tu de nham I,O,0,1
    return "-".join("".join(secrets.choice(alphabet) for _ in range(5)) for _ in range(4))


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("new")
    n.add_argument("--plan", choices=["trial", "term", "perpetual"], required=True)
    n.add_argument("--days", type=int, default=365)
    n.add_argument("--code", help="dung ma KH co san (mac dinh sinh ngau nhien 8 so)")
    n.add_argument("--unpaid", action="store_true", help="tao o trang thai chua thanh toan")
    s = sub.add_parser("status")
    s.add_argument("code"); s.add_argument("key")
    s.add_argument("value", choices=["active", "unpaid", "blocked"])
    e = sub.add_parser("extend")
    e.add_argument("code"); e.add_argument("key"); e.add_argument("--days", type=int, required=True)
    sub.add_parser("list")
    a = p.parse_args()

    data = load()
    if a.cmd == "new":
        code = a.code or new_customer_code()
        key = new_key()
        h = license_hash(code, key)
        expires = None if a.plan == "perpetual" else (date.today() + timedelta(days=a.days)).isoformat()
        data["licenses"][h] = {"plan": a.plan, "expires": expires,
                               "status": "unpaid" if a.unpaid else "active"}
        save(data)
        print(f"Ma khach hang : {code}\nLicense key   : {key}\nGoi           : {a.plan}\nHet han       : {expires or 'vinh vien'}")
        print("Gui ma + key rieng cho khach, roi commit license-status.json len GitHub.")
    elif a.cmd in ("status", "extend"):
        h = license_hash(a.code, a.key)
        if h not in data["licenses"]:
            sys.exit("Khong tim thay license nay.")
        if a.cmd == "status":
            data["licenses"][h]["status"] = a.value
        else:
            cur = data["licenses"][h].get("expires")
            base = max(date.today(), date.fromisoformat(cur)) if cur else date.today()
            data["licenses"][h]["expires"] = (base + timedelta(days=a.days)).isoformat()
        save(data)
        print("Da cap nhat:", data["licenses"][h])
    else:
        for h, v in data["licenses"].items():
            print(h[:12] + "...", v)


if __name__ == "__main__":
    main()
