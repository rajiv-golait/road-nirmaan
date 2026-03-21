import requests

SUPABASE_URL = "https://fxndnmlemadevxyovbql.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4bmRubWxlbWFkZXZ4eW92YnFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NTY3NTAsImV4cCI6MjA4NjEzMjc1MH0.e7kfK65csCBcv4Ob9jZrB_ONO424QsU1T092ZQiMUSc"

roles = [
    {"email": "commissioner@solapur.gov.in", "role": "commissioner", "ward_zone": None},
    {"email": "ac@solapur.gov.in", "role": "assistant_commissioner", "ward_zone": None},
    {"email": "chiefengineer@solapur.gov.in", "role": "chief_engineer", "ward_zone": None},
    {"email": "cityengineer@solapur.gov.in", "role": "chief_engineer", "ward_zone": None},
    {"email": "assistantengineer@solapur.gov.in", "role": "assistant_engineer", "ward_zone": "Central"},
    {"email": "deputyengineer@solapur.gov.in", "role": "deputy_engineer", "ward_zone": "Central"},
    {"email": "jrengineer@solapur.gov.in", "role": "junior_engineer", "ward_zone": "Central"},
    {"email": "workgang@solapur.gov.in", "role": "work_gang", "ward_zone": "Central"},
    {"email": "contractor@company.com", "role": "contractor", "ward_zone": "Central"},
    {"email": "nagarsevak@solapur.gov.in", "role": "nagarsevak", "ward_zone": "Central"},
    {"email": "citizen@gmail.com", "role": "citizen", "ward_zone": None}
]

url = f"{SUPABASE_URL}/rest/v1/user_roles"
headers = {
    "apikey": SUPABASE_KEY,
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

for r in roles:
    res = requests.post(url, headers=headers, json=r)
    print(f"{r['email']}: {res.status_code}")
