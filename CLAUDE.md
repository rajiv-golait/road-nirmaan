# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

### Flutter App
```bash
# Install dependencies
flutter pub get

# Run with Mapbox token (required for maps to render)
flutter run --dart-define=MAPBOX_TOKEN=pk.eyJ1...

# Run for Chrome
flutter run -d chrome --dart-define=MAPBOX_TOKEN=pk.eyJ1...

# Run for Android emulator
flutter run --dart-define=MAPBOX_TOKEN=pk.eyJ1...

# Lint/analyze code
flutter analyze

# Run tests
flutter test
```

### Flask Backend
```bash
cd "AI Integration"
# Recommended: use a venv (system Python may lack pip or Flask)
uv venv .venv
uv pip install -r requirements.txt --python .venv/Scripts/python.exe   # Windows
# uv pip install -r requirements.txt --python .venv/bin/python         # macOS/Linux
.venv/Scripts/python.exe app.py   # Windows — http://localhost:5000
```

### Environment Setup
Create a `.env` file in project root:
```env
MAPBOX_ACCESS_TOKEN=pk.eyJ1...
SUPABASE_URL=https://xxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbG...
```

## High-Level Architecture

### Stack Overview
- **Frontend:** Flutter with Material 3, uses `flutter_map` + `latlong2` for maps
- **Backend:** Flask (Python) with Roboflow API integration for pothole detection
- **Database:** Supabase (PostgreSQL + Auth + Storage)
- **External APIs:** Mapbox (geocoding/tiles), Roboflow (AI detection)

### Key Architectural Patterns

**State Management:**
- `ComplaintStore` (singleton via `ComplaintStore.instance`) is the central state manager
- Uses `ChangeNotifier` pattern; widgets listen via `notifyListeners()`
- All complaint mutations flow through `ComplaintService` for Supabase persistence, then update `ComplaintStore`

**Offline-First Design:**
- `ComplaintStore` maintains `_localOnlyComplaints` for offline fallback
- Network failures gracefully degrade to mock data via `MockDataSeeder`
- Images uploaded via `StorageService` with local path fallback

**Auto-Escalation:**
- Timer in `main.dart` runs `runAutoEscalation()` every 5 minutes + on app resume
- Escalation chain: JE → AE → DE → CE
- SLA hours defined in `utils/escalation_config.dart` based on severity
- `persistAutoEscalation()` persists to Supabase; failures are silently ignored

**AI Integration Flow:**
1. Images sent to Flask `/detect-flutter` endpoint
2. Roboflow API detects potholes, returns confidence + bounding boxes
3. Flask calculates severity score (0-10) and EPDO score using formula:
   - `EPDO = 0.4*severity + 0.3*traffic + 0.15*rainfall + 0.15*proximity`
4. Scores stored in complaint row via `createCitizenComplaint()`

**Role-Based Access:**
- Dashboards filtered by `currentHandler` field in complaint
- Ward-level filtering for JE/AE/DE using `getComplaintsForJE()` etc.
- CE and Commissioner see all complaints

### Critical File Relationships

**Constants and Config:**
- `lib/utils/constants.dart` - Mapbox token and Flask URL from `--dart-define`
- `lib/utils/escalation_config.dart` - SLA hours by role/severity

**Service Layer:**
- `lib/services/flask_ai_service.dart` - HTTP client for Flask backend
- `lib/services/complaint_service.dart` - Supabase CRUD operations
- `lib/services/complaint_store.dart` - Central state + business logic
- `lib/services/storage_service.dart` - Supabase Storage uploads

**Entry Points:**
- `lib/main.dart` - Sets up Supabase, initializes `ComplaintStore`, starts escalation timer
- `AI Integration/app.py` - Flask routes: `/detect-flutter`, `/check-duplicate`, `/verify-repair`

### Data Flow for New Complaint
1. Citizen dashboard → image capture
2. `FlaskAiService.analyzeImages()` → Flask `/detect-flutter`
3. `findNearbyOpenComplaints()` + `/check-duplicate` for spatial dedup (50m radius)
4. If duplicate: `addEvidenceToComplaint()`, else `createCitizenComplaint()`
5. `ComplaintService.createComplaint()` persists to Supabase
6. `ComplaintStore` updated, UI notified

### Database Schema Notes
- `complaints` table has `currentHandler`, `escalatedFrom`, `receivedAtCurrentLevel` for escalation tracking
- `complaint_events` table logs state changes
- Images stored as arrays of URLs in `images`, `before_images`, `after_images` columns
- SSIM verification scores stored in `ssim_score` column

### Testing Endpoints
Flask backend exposes:
- `POST /detect-flutter` - Analyze images, returns severity + EPDO scores
- `POST /check-duplicate` - Spatial duplicate detection
- `POST /verify-repair` - SSIM before/after comparison
