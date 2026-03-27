import os
import requests

"""
Creates Supabase Auth users for the demo dashboards.

Usage (PowerShell):
  $env:SUPABASE_URL="https://<your-project>.supabase.co"
  $env:SUPABASE_ANON_KEY="<your anon key>"
  python register_demo_accounts.py

Then run:
  supabase/demo_accounts.sql
in Supabase SQL editor to map roles + ward zones.
"""

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip()
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "").strip()

if not SUPABASE_URL or not SUPABASE_ANON_KEY:
  raise SystemExit(
    "Missing SUPABASE_URL or SUPABASE_ANON_KEY env vars.\n"
    "Set them before running this script."
  )

PASSWORD = "Demo@Road2024"

EMAILS = [
  "citizen@demo.roadnirman.in",
  "je.zone1@demo.roadnirman.in",
  "contractor@demo.roadnirman.in",
  "commissioner@demo.roadnirman.in",
  "ac@demo.roadnirman.in",
  "ce@demo.roadnirman.in",
  "de.zone1@demo.roadnirman.in",
  "ae.zone1@demo.roadnirman.in",
  "workgang.zone1@demo.roadnirman.in",
  "nagarsevak.zone1@demo.roadnirman.in",
]


def sign_up(email: str) -> tuple[int, str]:
  url = f"{SUPABASE_URL}/auth/v1/signup"
  headers = {"apikey": SUPABASE_ANON_KEY, "Content-Type": "application/json"}
  payload = {"email": email, "password": PASSWORD}
  r = requests.post(url, headers=headers, json=payload, timeout=30)
  return r.status_code, r.text


def main() -> None:
  print("Creating demo Auth users (signup).")
  print("If a user already exists, Supabase may return 400/422 — that's ok.")
  for email in EMAILS:
    code, body = sign_up(email)
    ok = code in (200, 201)
    print(f"{email}: {code} {'OK' if ok else 'CHECK'}")
    if not ok:
      print(body)
  print("\nDone. Now run supabase/demo_accounts.sql in Supabase SQL Editor.")


if __name__ == "__main__":
  main()

