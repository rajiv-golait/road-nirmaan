# RoadNirman

**Smart road damage reporting and municipal workflow** for Solapur Municipal Corporation — citizen complaints, AI-assisted severity (Roboflow + Flask), escalation (JE → AE → DE → CE), and role-based dashboards (engineers, contractor, commissioner).

---

## Table of contents

1. [Features](#features)
2. [Architecture](#architecture)
3. [Repository layout](#repository-layout)
4. [Prerequisites](#prerequisites)
5. [Quick start](#quick-start)
6. [Environment variables](#environment-variables)
7. [Supabase (database, auth, storage)](#supabase-database-auth-storage)
8. [Flutter app](#flutter-app)
9. [Flask AI backend](#flask-ai-backend)
10. [Real device vs emulator (Flask URL)](#real-device-vs-emulator-flask-url)
11. [Compile-time flags (`--dart-define`)](#compile-time-flags---dart-define)
12. [Demo & judging](#demo--judging)
13. [Troubleshooting](#troubleshooting)
14. [License](#license)

---

## Features

- **Citizens** — Submit reports with photos, GPS (or approximate location), AI analysis, duplicate detection near existing open complaints.
- **Offline resilience** — Local-only complaint IDs if Supabase insert fails; optional mock data when explicitly enabled.
- **Staff dashboards** — Junior engineer through commissioner: maps, SLA-style escalation, assignments, verification flows.
- **AI pipeline** — Images → Flask `/detect-flutter` → Roboflow pothole detection → severity / EPDO-style scoring; optional offline estimate if Flask is unreachable.
- **Repair verification** — Before/after images and SSIM via Flask `/verify-repair`.

---

## Architecture

```
┌─────────────────┐     ┌──────────────────────────┐     ┌─────────────────┐
│  Flutter app    │────▶│  Supabase                │     │  Mapbox         │
│  (Material 3)   │     │  PostgreSQL + Auth +     │     │  tiles / geo    │
│                 │     │  Storage                 │     └─────────────────┘
└────────┬────────┘     └──────────────────────────┘
         │
         │  HTTP (multipart / JSON)
         ▼
┌─────────────────┐     ┌──────────────────────────┐
│  Flask (Python) │────▶│  Roboflow Inference API  │
│  AI Integration/│     │  (pothole detection)       │
└─────────────────┘     └──────────────────────────┘
```

Central state: **`ComplaintStore`** (singleton) + **`ComplaintService`** (Supabase CRUD). See `CLAUDE.md` in the repo for deeper file-level relationships.

---

## Repository layout

| Path | Purpose |
|------|--------|
| `lib/` | Flutter UI, services, models, utils |
| `AI Integration/` | Flask app: `/detect-flutter`, `/check-duplicate`, `/verify-repair`, `/health` |
| `supabase/` | SQL: `schema.sql`, `rls.sql`, `storage.sql`, `migrate.sql`, `seed.sql`, `demo_accounts.sql` |
| `assets/` | Images and static assets |
| `.vscode/launch.json` | Optional **dart-define** presets (e.g. emulator vs real device Flask URL) |
| `.env.example` | Template for secrets — copy to `.env` (not committed) |

---

## Prerequisites

| Tool | Notes |
|------|--------|
| **Flutter** | SDK ≥ 3.10 (see `pubspec.yaml` `environment.sdk`) |
| **Dart** | Bundled with Flutter |
| **Python** | 3.9+ recommended for Flask backend |
| **Supabase** | Project + SQL access (SQL Editor) |
| **Mapbox** | Public token for map tiles / geocoding (Flutter + Flask) |
| **Roboflow** | API key for inference (serverless URL in `requirements.txt` / env) |

---

## Quick start

### 1. Clone and install Flutter dependencies

```bash
cd Road_Nirman-main
flutter pub get
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env: MAPBOX_ACCESS_TOKEN, ROBOFLOW_* (for Flask). See below.
```

### 3. Apply Supabase SQL (order matters)

In **Supabase Dashboard → SQL Editor**, run in order:

1. `supabase/schema.sql` — tables
2. `supabase/rls.sql` — row level security
3. `supabase/storage.sql` — storage buckets (if used)
4. `supabase/migrate.sql` — additive columns on existing DBs
5. `supabase/seed.sql` — optional demo data (e.g. 50 complaints + `user_roles` seeds)

### 4. Flutter: point Supabase URL + anon key

The app initializes Supabase in `lib/main.dart` (`Supabase.initialize(...)`). Replace with your project URL and **anon** key, or refactor to `--dart-define` or a config loader if you prefer not to hardcode.

### 5. Run Flask backend

```bash
cd "AI Integration"
pip install -r requirements.txt
python app.py
```

Listens on **`0.0.0.0:5000`** (reachable from LAN for physical devices). Check **`GET /health`** for JSON status and `roboflow_key_set` / `mapbox_key_set`.

### 6. Run the Flutter app

```bash
flutter run --dart-define=MAPBOX_TOKEN=YOUR_PK_TOKEN --dart-define=FLASK_URL=http://YOUR_LAN_IP:5000
```

Use **`FLASK_URL=http://10.0.2.2:5000`** (default in `lib/utils/constants.dart`) only for **Android emulator**; use your PC’s **LAN IP** for a **physical phone** on the same Wi‑Fi.

---

## Environment variables

### Project root `.env` (Flask / Python)

Used by `AI Integration/app.py` (loaded from repo root). **Do not commit `.env`.**

| Variable | Required | Purpose |
|----------|----------|---------|
| `MAPBOX_ACCESS_TOKEN` | Strongly recommended | Geocoding in Flask; Mapbox-backed features |
| `ROBOFLOW_API_KEY` | **Required** (app raises if missing) | Roboflow inference |
| `ROBOFLOW_MODEL_ID` | Optional | Default: `pothole-detection-gv5e7/3` |
| `ROBOFLOW_API_URL` | Optional | Default: `https://serverless.roboflow.com` |

Copy from **`.env.example`** and fill in real values.

### Flutter

- **`MAPBOX_TOKEN`** — pass via `--dart-define=MAPBOX_TOKEN=...` for map tiles (`lib/utils/map_tile_config.dart`).
- **`FLASK_URL`** — pass via `--dart-define=FLASK_URL=...` (see [constants.dart](lib/utils/constants.dart)).

---

## Supabase (database, auth, storage)

- **Tables** — `complaints`, `profiles`, `user_roles`, `complaint_votes`, `complaint_events`, etc. (see `schema.sql`).
- **Auth** — Email/password; register citizens in-app; create staff accounts in Supabase Auth and align `user_roles` / `profiles`.
- **Storage** — Complaint images uploaded via app services (see `storage.sql` for buckets/policies).

Optional demo SQL: **`supabase/demo_accounts.sql`** (after creating matching users in Auth).

---

## Flutter app

```bash
flutter pub get
flutter analyze
flutter run
```

**Web / Chrome:**

```bash
flutter run -d chrome --dart-define=MAPBOX_TOKEN=pk... --dart-define=FLASK_URL=http://localhost:5000
```

### Main entry

- `lib/main.dart` — Supabase init, `ComplaintStore`, escalation timer.

### Key packages

See `pubspec.yaml`: `supabase_flutter`, `flutter_map`, `latlong2`, `geolocator`, `image_picker`, `http`, etc.

---

## Flask AI backend

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Liveness + key flags |
| `/detect-flutter` | POST | Multipart images + lat/lng → JSON severity, EPDO, detections |
| `/check-duplicate` | POST | JSON: nearby complaints vs radius (Haversine) |
| `/verify-repair` | POST | Before/after images → SSIM, verdict |

---

## Real device vs emulator (Flask URL)

| Target | Typical `FLASK_URL` |
|--------|---------------------|
| Android emulator | `http://10.0.2.2:5000` (default in code) |
| iOS simulator / desktop | `http://127.0.0.1:5000` or `http://localhost:5000` |
| Physical phone (same Wi‑Fi as PC) | `http://<YOUR_PC_LAN_IP>:5000` |

Ensure Windows Firewall allows inbound **TCP 5000** on private networks if the phone cannot reach the PC.

---

## Compile-time flags (`--dart-define`)

| Flag | Default | Meaning |
|------|---------|---------|
| `MAPBOX_TOKEN` | empty | Mapbox tiles; empty may fall back to OSM depending on config |
| `FLASK_URL` | `http://10.0.2.2:5000` | AI backend base URL |
| `ALLOW_MOCK_DATA` | `false` | Local mock complaints / seeder when `true` |
| `ALLOW_DEMO_LOGIN` | `false` | Demo password path in `demo_role_router` (dev only) |

Example production-style run:

```bash
flutter run --dart-define=ALLOW_MOCK_DATA=false --dart-define=ALLOW_DEMO_LOGIN=false --dart-define=MAPBOX_TOKEN=pk... --dart-define=FLASK_URL=http://192.168.1.10:5000
```

---

## Demo & judging

- Use **`ALLOW_MOCK_DATA=false`** and **`ALLOW_DEMO_LOGIN=false`** so judges see real Supabase data and auth.
- Run Flask with valid **Roboflow** + **Mapbox** keys; submit a **real** complaint and confirm **`ai_source`** / `severity_score` in Supabase when using live AI.
- Optional: VS Code **Run and Debug** → configurations in `.vscode/launch.json` if present.

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Map blank / no tiles | `MAPBOX_TOKEN` set; `flutter run` shows defines |
| AI always “offline” / fallback | Phone `FLASK_URL` = PC LAN IP; Flask `host=0.0.0.0`; firewall; `/health` from phone browser |
| `ROBOFLOW_API_KEY not set` | `.env` in **project root** (parent of `AI Integration`), restart Flask |
| Supabase errors on insert | Run `migrate.sql`; RLS policies; `auth` session |
| Analyzer noise | `flutter analyze` — fix **error** first; warnings/info are often style/deprecations |

---

## Contributing

1. Branch from `main` (or your default branch).
2. Run `flutter analyze` before PRs.
3. Never commit `.env` or keystores.

---

## License

This project is developed for **Solapur Municipal Corporation** / hackathon use. Add a SPDX license file if you release publicly.

---

## Acknowledgments

- **Supabase** — PostgreSQL, Auth, Storage  
- **Mapbox** — Maps and geocoding  
- **Roboflow** — Pothole detection model  

For internal developer notes, see **`CLAUDE.md`**.
