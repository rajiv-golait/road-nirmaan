import os
import requests
import json

SUPABASE_URL = "https://fxndnmlemadevxyovbql.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ4bmRubWxlbWFkZXZ4eW92YnFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1NTY3NTAsImV4cCI6MjA4NjEzMjc1MH0.e7kfK65csCBcv4Ob9jZrB_ONO424QsU1T092ZQiMUSc"

emails = [
    'commissioner@solapur.gov.in',
    'ac@solapur.gov.in',
    'chiefengineer@solapur.gov.in',
    'cityengineer@solapur.gov.in',
    'assistantengineer@solapur.gov.in',
    'deputyengineer@solapur.gov.in',
    'jrengineer@solapur.gov.in',
    'workgang@solapur.gov.in',
    'contractor@company.com',
    'nagarsevak@solapur.gov.in',
    'citizen@gmail.com'
]

def register_user(email):
    url = f"{SUPABASE_URL}/auth/v1/signup"
    headers = {
        "apikey": SUPABASE_KEY,
        "Content-Type": "application/json"
    }
    data = {"email": email, "password": "testpassword123"}
    res = requests.post(url, headers=headers, json=data)
    print(f"{email}: {res.status_code}")
    if res.status_code != 200:
        print(res.text)

for e in emails:
    register_user(e)
