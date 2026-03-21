You are the lead engineer on RoadNirman, a hackathon project.
The audit is done. Stop analyzing. Start building.

Your job is to execute a precise, ordered fix plan.
No suggestions. No "you could also consider." Just build.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CONTEXT (read once, don't re-explain it)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stack:
- Flutter app (roadnirman) — citizen + authority dashboards
- Flask backend (AI Integration/app.py) — Roboflow pothole detection
- Supabase — database + storage (schema NOT yet deployed)
- Mapbox — map tiles + geocoding (token in .env, unused everywhere)

Current broken state (from audit):
- AiRecommendationService in Flutter = pure fake (filename hash math)
- Flutter never calls Flask /detect endpoint
- Mapbox token = hardcoded "YOUR_MAPBOX_TOKEN" in 3 places
- No Supabase schema in repo
- Severity score = keyword "water" → High, else Medium
- Auto-escalation = in-memory only, never persists
- EPDO formula = not implemented anywhere
- Spatial dedup = zero implementation
- SSIM before/after = UI exists, logic missing
- Roboflow bbox coords = not scaled (will produce wrong area values)

Real tokens belong in `.env` only (never commit `.env`):
MAPBOX_ACCESS_TOKEN=<from Mapbox account>
ROBOFLOW_API_KEY=<from Roboflow dashboard>

Roboflow config in Flask reads from `.env` (see `AI Integration/app.py`).

MODEL_ID example: `pothole-detection-gv5e7/3`

Flask /detect endpoint = working, returns:
{
  success, total_images, results[],
  average_severity_score, priority, priority_color,
  scoring_weights, repair_recommendations
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EXECUTION PLAN — DO THESE IN ORDER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Each phase has a STOP CONDITION.
Do not start Phase N+1 until Phase N stop condition passes.

──────────────────────────────────────
PHASE 1 — Token plumbing (30 min)
──────────────────────────────────────

Goal: Mapbox token flows from .env to Flutter and Flask.
No hardcoded strings remain.

Tasks:
1. Flask (AI Integration/app.py):
   Replace:
     MAPBOX_API_KEY = "YOUR_MAPBOX_TOKEN"
   With:
     import os
     from dotenv import load_dotenv
     load_dotenv()
     MAPBOX_API_KEY = os.getenv("MAPBOX_ACCESS_TOKEN", "")
   Add python-dotenv to requirements.txt.

2. Flutter (ALL files containing "YOUR_MAPBOX_TOKEN"):
   - lib/utils/constants.dart — add:
       static const String mapboxToken =
         String.fromEnvironment('MAPBOX_TOKEN', defaultValue: '');
   - Replace every hardcoded 'YOUR_MAPBOX_TOKEN' string across
     all dashboard files with AppConstants.mapboxToken
   - Update launch config / Makefile to pass:
       --dart-define=MAPBOX_TOKEN=<token from .env>

3. Verify: Run Flutter with --dart-define. Open citizen dashboard.
   Map tiles should render (Solapur streets visible, not blank grey).

STOP CONDITION:
  Map tiles render in citizen_dashboard AND
  Flask /detect returns geocoding results (not empty location params)

──────────────────────────────────────
PHASE 2 — Supabase schema (2 hours)
──────────────────────────────────────

Goal: Fresh Supabase project can be set up from repo alone.
No more silent fallback to mock data in judge environment.

Tasks:
1. Create supabase/schema.sql with these tables
   (infer exact columns from complaint_service.dart and
   complaint_store.dart — every .from('tablename').select()
   and .insert(row) call tells you the schema):

   Tables needed:
   - profiles (id, email, full_name, role, ward_zone, created_at)
   - user_roles (user_id, role, ward_zone)
   - complaints (
       id, title, description, damage_type, severity,
       status, priority_score, epdo_score,
       latitude, longitude, location_text,
       ward_zone, assigned_to, contractor_id,
       images text[], before_images text[], after_images text[],
       ssim_score float, verification_status,
       created_by, created_at, updated_at,
       sla_deadline, escalated_from, current_handler,
       received_at_current_level, auto_escalated_at
     )
   - complaint_votes (id, complaint_id, user_id, created_at)
   - complaint_events (
       id, complaint_id, event_type,
       from_status, to_status, actor_id,
       notes, created_at
     )

2. Create supabase/rls.sql with Row Level Security policies:
   - Citizens: can insert complaints, read own complaints
   - Junior Engineers: read/update complaints in their ward_zone
   - Senior roles: read all complaints
   - Contractors: read complaints assigned to them, update
     before_images/after_images/verification_status
   - Commissioner: full read access

3. Create supabase/storage.sql:
   - Bucket: complaints (public read, authenticated write)
   - Bucket: verifications (authenticated read/write)

4. Create supabase/seed.sql:
   50 mock potholes seeded across Solapur's 6 wards
   with realistic lat/lng coordinates, varied severity,
   varied status (Open/Assigned/InProgress/Resolved),
   and calculated epdo_score values.
   Use actual Solapur coordinates:
   Center: 17.6868° N, 75.9074° E
   Spread complaints across a ~15km radius.

5. Add README section: "Database Setup"
   with exact commands to run schema + seed.

STOP CONDITION:
  Fresh Supabase project + run schema.sql + seed.sql →
  Flutter app loads 50 real complaints from Supabase
  (not mock data). Confirm via network tab or debug log.

──────────────────────────────────────
PHASE 3 — Real AI pipeline (4 hours)
──────────────────────────────────────

Goal: Flutter → Flask → Roboflow → real score → stored in DB.
AiRecommendationService dummy is fully replaced.

Tasks:
1. Fix Roboflow bbox coordinate scaling in Flask first:
   After getting predictions, check if coords are normalized
   (values between 0-1) or pixel-space (values > 1).
   Add auto-detection:
     img = Image.open(filepath)
     img_w, img_h = img.size
     # If x,y,w,h are all ≤ 1.0, they're normalized
     is_normalized = all(
       p.get('x',0) <= 1.0 and p.get('y',0) <= 1.0
       for p in predictions[:3]
     )
     if is_normalized:
       x = prediction['x'] * img_w
       y = prediction['y'] * img_h
       width = prediction['width'] * img_w
       height = prediction['height'] * img_h

2. Add EPDO scoring to Flask alongside existing severity score:
   After calculate_severity_score() runs, also compute:

   def calculate_epdo_score(detections, road_classification,
                            traffic_level, rainfall_risk,
                            proximity_score):
     # S_AI: normalize severity (0-10) to (0-1)
     s_ai = severity_score / 10.0

     # T_OSM: map road_classification to traffic weight
     osm_weights = {
       'interstate': 1.0, 'highway': 0.85,
       'arterial': 0.65, 'collector': 0.45,
       'local': 0.25, 'residential': 0.15
     }
     t_osm = osm_weights.get(road_classification, 0.5)

     # R_historical: map rainfall risk (hardcode Solapur zones)
     # Solapur avg: 550mm/year, monsoon risk = medium
     r_hist = {'high': 1.0, 'medium': 0.6, 'low': 0.3}.get(
       rainfall_risk, 0.6
     )

     # C_proximity: 1.0 if near hospital/fire station, else 0.2
     c_prox = proximity_score  # float 0-1, passed in

     epdo = (0.40 * s_ai) + (0.30 * t_osm) + \
            (0.15 * r_hist) + (0.15 * c_prox)
     return round(epdo * 10, 2)  # scale to 0-10

   Add rainfall_risk and proximity_score params to /detect.
   Default rainfall_risk = 'medium' (Solapur baseline).
   Default proximity_score = 0.2.

   Return both severity_score AND epdo_score in response.

3. Add /detect-flutter endpoint (or update /detect) to:
   - Accept multipart/form-data with:
       images[] (files)
       latitude (float)
       longitude (float)
       rainfall_risk (string, optional)
       proximity_score (float, optional)
   - Return JSON matching this Flutter model:
     {
       "success": true,
       "severity_score": 6.4,
       "epdo_score": 7.1,
       "priority": "HIGH",
       "total_potholes": 3,
       "repair_recommendations": {
         "recommended_road_type": "Premix",
         "worker_type": "Contractor",
         "urgency": "HIGH",
         "timeline": "1-2 weeks",
         "summary": "..."
       },
       "detections": [
         {"id":1, "confidence":87.3, "width":245, "height":198}
       ]
     }

4. In Flutter, create lib/services/flask_ai_service.dart:
   class FlaskAiService {
     static const String _baseUrl =
       String.fromEnvironment('FLASK_URL',
         defaultValue: 'http://10.0.2.2:5000');  // Android emulator

     static Future<Map<String, dynamic>> analyzeImages({
       required List<String> imagePaths,
       required double latitude,
       required double longitude,
     }) async {
       final request = http.MultipartRequest(
         'POST', Uri.parse('$_baseUrl/detect-flutter'));

       for (final path in imagePaths) {
         request.files.add(
           await http.MultipartFile.fromPath('images', path));
       }
       request.fields['latitude'] = latitude.toString();
       request.fields['longitude'] = longitude.toString();

       final response = await request.send();
       final body = await response.stream.bytesToString();
       return jsonDecode(body) as Map<String, dynamic>;
     }
   }

5. In citizen_dashboard.dart, after image capture:
   Replace the call to AiRecommendationService.analyzeSingleImage()
   with FlaskAiService.analyzeImages().
   Keep AiRecommendationService as fallback if Flask call fails
   (network errors during demo should degrade gracefully,
   not crash).

6. Store epdo_score in the complaint row when creating complaint.
   Update createCitizenComplaint() to accept and persist
   epdo_score and total_potholes from the AI response.

7. Delete (or clearly stub out) the fake scoring logic in
   complaint_store.dart:651:
     'severity': damageType.toLowerCase().contains('water')
       ? 'High' : 'Medium'
   Replace with severity derived from Flask response.

STOP CONDITION:
  Take a real photo of a road (or any surface).
  Submit report in Flutter.
  Supabase complaints table receives a new row with:
  - non-null severity_score (float, not "Medium"/"High" string)
  - non-null epdo_score
  - total_potholes > 0
  - real GPS coordinates

──────────────────────────────────────
PHASE 4 — Spatial dedup (2 hours)
──────────────────────────────────────

Goal: Submitting two reports within 50m of each other
merges the second into the first. No PostGIS required.

Tasks:
1. In Flask, add /check-duplicate endpoint:
   def haversine(lat1, lon1, lat2, lon2):
     R = 6371000  # meters
     phi1, phi2 = math.radians(lat1), math.radians(lat2)
     dphi = math.radians(lat2 - lat1)
     dlambda = math.radians(lon2 - lon1)
     a = math.sin(dphi/2)**2 + \
         math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
     return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

   @app.route('/check-duplicate', methods=['POST'])
   def check_duplicate():
     data = request.json
     new_lat = data['latitude']
     new_lng = data['longitude']
     existing = data['existing_complaints']
     # existing = list of {id, latitude, longitude, status}

     DEDUP_RADIUS_METERS = 50

     for complaint in existing:
       if complaint['status'] in ['Resolved', 'Closed']:
         continue
       dist = haversine(new_lat, new_lng,
                        complaint['latitude'],
                        complaint['longitude'])
       if dist <= DEDUP_RADIUS_METERS:
         return jsonify({
           'is_duplicate': True,
           'master_complaint_id': complaint['id'],
           'distance_meters': round(dist, 1)
         })

     return jsonify({'is_duplicate': False})

2. In Flutter, before createCitizenComplaint() is called:
   - Fetch nearby open complaints from Supabase
     (bounding box query: ±0.001 degrees lat/lng ≈ ~100m)
   - POST to /check-duplicate with new coords + nearby list
   - If is_duplicate: true →
       show SnackBar: "This issue is already reported (Xm away).
       Your photo has been added as evidence."
       Call addEvidenceToComplaint(master_id, new_images)
       instead of createCitizenComplaint()
   - If is_duplicate: false → proceed normally

3. Add addEvidenceToComplaint() to ComplaintStore:
   Appends new images to existing complaint's images array
   in Supabase. Increments a vote/confirmation count.

STOP CONDITION:
  Submit report at lat A.
  Submit second report within 30m of lat A.
  Second submission shows "already reported" SnackBar.
  First complaint in Supabase has additional image appended.
  No second complaint row created.

──────────────────────────────────────
PHASE 5 — Auto-escalation persistence (1 hour)
──────────────────────────────────────

Goal: Escalation state survives app restart.

Tasks:
1. Wire ComplaintService.applyAutoEscalation() into
   ComplaintStore.runAutoEscalation():
   Currently runAutoEscalation() only mutates in-memory maps.
   After each mutation, call:
     await ComplaintService.instance.applyAutoEscalation(
       complaintId: complaint['id'],
       newHandler: nextHandler,
       escalatedFrom: currentHandler,
       autoEscalatedAt: DateTime.now().toIso8601String(),
     )

2. Add a periodic trigger in main.dart or app lifecycle:
   Run runAutoEscalation() on app resume + every 30 minutes.
   Use Timer.periodic for background cadence.

3. Add complaint_events row for each auto-escalation:
   event_type: 'AUTO_ESCALATED'
   from_status: currentHandler
   to_status: nextHandler
   actor_id: 'SYSTEM'

STOP CONDITION:
  Complaint is overdue by SLA.
  Close and reopen app.
  Complaint still shows escalated handler (not original).
  complaint_events table has AUTO_ESCALATED row.

──────────────────────────────────────
PHASE 6 — SSIM verification (2 hours)
──────────────────────────────────────

Goal: Contractor uploads "After" photo.
System scores it. Pass = complaint closes. Fail = rejected.

Tasks:
1. Add /verify-repair endpoint to Flask:
   from skimage.metrics import structural_similarity as ssim
   import cv2, numpy as np

   @app.route('/verify-repair', methods=['POST'])
   def verify_repair():
     before_file = request.files['before_image']
     after_file = request.files['after_image']

     before = cv2.imdecode(
       np.frombuffer(before_file.read(), np.uint8),
       cv2.IMREAD_GRAYSCALE)
     after = cv2.imdecode(
       np.frombuffer(after_file.read(), np.uint8),
       cv2.IMREAD_GRAYSCALE)

     # Resize to same dimensions
     h = min(before.shape[0], after.shape[0])
     w = min(before.shape[1], after.shape[1])
     before = cv2.resize(before, (w, h))
     after = cv2.resize(after, (w, h))

     score, _ = ssim(before, after, full=True)

     # Inverse logic: high SSIM = unchanged = BAD repair
     # Low SSIM = surface changed = GOOD repair (new asphalt)
     PASS_THRESHOLD = 0.75  # score BELOW this = pass
     passed = score < PASS_THRESHOLD

     import hashlib, time
     hash_input = f"{score}{time.time()}".encode()
     verification_hash = hashlib.sha256(hash_input).hexdigest()

     return jsonify({
       'passed': passed,
       'ssim_score': round(score, 4),
       'verdict': 'REPAIR_VERIFIED' if passed else 'REPAIR_REJECTED',
       'verification_hash': verification_hash if passed else None,
       'message': (
         'Repair verified. Surface texture change confirmed.'
         if passed else
         'Repair rejected. Surface appears unchanged. Resubmit.'
       )
     })
   Add scikit-image, opencv-python to requirements.txt.

2. In Flutter verify_complaint_screen.dart,
   after uploading after_images to Supabase storage,
   also POST before + after to /verify-repair.
   Show result:
   - passed=true → green banner "Repair Verified ✓" + hash
   - passed=false → red banner "Rejected — surface unchanged"
   Store ssim_score and verification_hash in complaint row.
   If passed: update complaint status → 'Resolved'.

STOP CONDITION:
  Upload same image as before+after → rejected (SSIM ≈ 1.0)
  Upload pothole image as before, smooth road as after → verified
  Complaint status updates to Resolved in Supabase.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DEMO HARDENING (after all phases done)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

These are the final 3 things before demo day.
Do not skip these.

1. Seed the admin dashboard:
   Run supabase/seed.sql to load 50 Solapur potholes.
   Verify commissioner_dashboard shows real heatmap pins
   with EPDO color coding (red ≥ 8, orange 5-8, green < 5).

2. Prepare the 3 demo scripts:
   Script A — Citizen report:
     Open app → camera → point at pothole image → AI detects →
     GPS captured → submit → duplicate check runs →
     complaint appears on JE dashboard with EPDO score.

   Script B — Duplicate detection:
     Submit second report from same location →
     "Already reported 23m away" → first complaint gets
     extra evidence image appended.

   Script C — Contractor verification:
     Open contractor_dashboard → pick assigned complaint →
     upload before (pothole) + after (smooth road) →
     AI verifies → complaint closes → hash displayed.

3. Offline fallback check:
   Turn off internet. Open app.
   All 3 dashboards must still display mock data.
   No crashes. No blank screens.
   Show judges "works even offline" as bonus.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RULES WHILE BUILDING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Never skip a STOP CONDITION to "save time."
   A broken Phase 3 built on broken Phase 2 = demo failure.

2. When something is unclear in the existing code,
   read the file first. Don't assume. Don't rewrite
   what already works.

3. If a phase is blocked by something unexpected,
   state the blocker clearly in one sentence,
   then propose the minimal fix to unblock it.
   Do not redesign.

4. All new Flask endpoints must have a
   try/except block that returns
   {"error": str(e)}, 500
   Crashes during demo = instant credibility loss.

5. Flutter HTTP calls must have a timeout:
   http.MultipartRequest → client.send(request)
     .timeout(Duration(seconds: 15))
   Catch TimeoutException → fall back to
   AiRecommendationService (offline mode).

6. Every Supabase write must be wrapped in try/catch.
   On failure: store locally, show "Saved offline,
   will sync when connected."

Start with Phase 1.
Show me the diff for each file you change.
After each phase, confirm the STOP CONDITION passed
before proceeding.