import urllib.request
import urllib.error
import json

SUPABASE_URL = "https://fxndnmlemadevxyovbql.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4bmRubWxlbWFkZXZ4eW92YnFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NTY3NTAsImV4cCI6MjA4NjEzMjc1MH0.e7kfK65csCBcv4Ob9jZrB_ONO424QsU1T092ZQiMUSc"

accounts = [
    {"email": "citizen@demo.roadnirman.in", "role": "citizen", "ward_zone": None},
    {"email": "je.zone1@demo.roadnirman.in", "role": "junior_engineer", "ward_zone": "Zone 1"},
    {"email": "je.zone2@demo.roadnirman.in", "role": "junior_engineer", "ward_zone": "Zone 2"},
    {"email": "je.zone3@demo.roadnirman.in", "role": "junior_engineer", "ward_zone": "Zone 3"},
    {"email": "ae@demo.roadnirman.in", "role": "assistant_engineer", "ward_zone": "Central"},
    {"email": "contractor@demo.roadnirman.in", "role": "contractor", "ward_zone": "Central"},
    {"email": "ce@demo.roadnirman.in", "role": "chief_engineer", "ward_zone": None},
    {"email": "commissioner@demo.roadnirman.in", "role": "commissioner", "ward_zone": None},
    {"email": "workgang@demo.roadnirman.in", "role": "work_gang", "ward_zone": "Central"}
]

PASSWORD = "Demo@Road2024"

def make_request(url, headers, method="GET", data=None):
    req = urllib.request.Request(url, headers=headers, method=method)
    try:
        data_bytes = json.dumps(data).encode('utf-8') if data else None
        with urllib.request.urlopen(req, data=data_bytes) as response:
            return response.getcode(), response.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except Exception as e:
        return 500, str(e)

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

print("Checking existing accounts...")
roles_url = f"{SUPABASE_URL}/rest/v1/user_roles"
status_code, text = make_request(roles_url, headers=headers, method="GET")

existing_emails = []
if status_code == 200:
    data = json.loads(text)
    existing_emails = [d.get('email') for d in data]
    print(f"Found {len(existing_emails)} user roles in database.")
else:
    print(f"Error checking accounts: {status_code} - {text}")

print("\nRegistering missing users to Auth...")
for acc in accounts:
    if acc['email'] in existing_emails:
        print(f"[x] {acc['email']} already exists.")
        continue
        
    url = f"{SUPABASE_URL}/auth/v1/signup"
    data = {"email": acc['email'], "password": PASSWORD}
    code, rsp_text = make_request(url, headers=headers, method="POST", data=data)
    print(f"Auth {acc['email']}: {code}")

print("\nSeeding user roles for missing users...")
for acc in accounts:
    if acc['email'] in existing_emails:
        continue
        
    role_data = {
        "email": acc['email'],
        "role": acc['role'],
        "ward_zone": acc['ward_zone']
    }
    code, rsp_text = make_request(roles_url, headers=headers, method="POST", data=role_data)
    print(f"Role {acc['email']}: {code} - {rsp_text}")
