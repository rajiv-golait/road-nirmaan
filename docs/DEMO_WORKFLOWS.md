# Road Nirman — End-to-end demo scripts

Use these with a running Flask backend (`/detect-flutter`, `/check-duplicate`, `/verify-repair`), Supabase, and `WardAssignmentService.refresh()` after login (handled from login flow).

**Accounts (from `supabase/seed.sql`, adjust if your project uses different emails):**

| Role | Example email | Ward / notes |
|------|----------------|--------------|
| Citizen | `citizen@gmail.com` | — |
| Junior Engineer | `je.central@smcsolapur.gov.in` | `Central` (matches city zones) |
| Contractor | `contractor1@smcsolapur.gov.in` | `North` |
| Chief Engineer | `ce@smcsolapur.gov.in` or `chiefengineer@solapur.gov.in` | Sees all / CE queue |

---

## Five implementation checks (code review)

| # | Check | State |
|---|--------|--------|
| 1 | Citizen sees **severity score**, **EPDO score**, **priority**, **pothole count** in the post-submit **Report Submitted** dialog when AI returned data | **FIXED** — `citizen_dashboard.dart` success dialog |
| 2 | Commissioner map pins use **EPDO** color: red ≥ 8, orange 5–8, green below 5; grey if no EPDO | **FIXED** — `LegacyDashboardAdapter.mapLocations` + `_markerColorFromEpdo` |
| 3 | JE list uses `ComplaintStore.getComplaintsForJE(WardAssignmentService.assignedWards)`; wards containing **pending** or **unknown** match all JEs until zone is resolved | **CONFIRMED** — `complaint_store.dart` |
| 4 | CE dashboard shows **Pending CE** via `LegacyDashboardAdapter.ceEscalatedComplaints()` → `getComplaintsPendingCEAuthorization()` (`status == 'PendingCEApproval'`) | **CONFIRMED** — `chief_engineer_dashboard.dart` |
| 5 | After SSIM success, `VerifyComplaintScreen` sends `status: 'PendingCEApproval'` (not `Resolved`) via `submitForCEAuthorization` | **CONFIRMED** — `verify_complaint_screen.dart` |

**Important:** `PendingCEApproval` is a **camelCase** status in the app. `DashboardMetrics` and `LegacyDashboardAdapter._isVerifiedAndAssigned` were updated to recognize **`pendingceapproval`** when lowercased so metrics and “assigned” lists stay correct.

---

## SCRIPT A — Citizen reports a pothole

**Goal:** New complaint in Supabase with AI fields; JE can see it.

**Step 1:** Log in as **citizen** (`citizen@gmail.com` or your seed citizen).

**Screen shows:** Citizen home / dashboard.

**Step 2:** Open **Report** / **New complaint** (the flow that captures category, description, and **at least one photo**). Grant **camera** or **gallery** and **location** when prompted.

**Screen shows:** Form with category, description, photo thumbnails, and location (or “approximate” dialog if GPS fails).

**Step 3:** Tap **Submit** (or equivalent).

**Screen shows:**

- SnackBar: **“Analyzing images with AI…”**
- If Flask returns 200: AI runs; then **Report Submitted** dialog with thank-you text and, when AI succeeded, an **AI analysis** block: **Severity score**, **EPDO score**, **Potholes detected**, **Priority**.
- If Flask is unreachable: catch in `citizen_dashboard` → fallback **offline** model; orange SnackBar: **“Could not reach AI server…”**; `ai_source` may be **OFFLINE_ESTIMATE** or **UNKNOWN** depending on path.

**Console log (Flutter):**

- `═══ AI PIPELINE START ═══`
- On success: `═══ AI RESULT (ROBOFLOW REAL) ═══` plus potholes / severity / EPDO / priority (`flask_ai_service.dart`).

**Duplicate check (before AI):**

- `ComplaintStore.findNearbyOpenComplaints` + `FlaskAiService.checkDuplicate`.
- If duplicate: evidence attached to existing complaint; SnackBar **“Duplicate complaint found…”**; **no new row** for a new id.
- If duplicate check throws: dialog **“Duplicate check unavailable”** — user may cancel or **Submit anyway**.

**Supabase after (new complaint, not duplicate):**

```sql
SELECT id, latitude, longitude, ward_zone, status,
       severity_score, epdo_score, total_potholes, ai_source,
       location_is_approximate, priority_score, assigned_to
FROM complaints
ORDER BY created_at DESC
LIMIT 1;
```

**Expected (typical):**

- `status` = **`Open`**
- `ward_zone` = **`Ward Pending`** (until you add geocoding to zone)
- `latitude` / `longitude` = real GPS or approximate center if user accepted
- `severity_score`, `epdo_score` = numeric (0–10 scale from Flask)
- `total_potholes` ≥ 0
- `ai_source` = **`ROBOFLOW_REAL`** or **`OFFLINE_ESTIMATE`**
- `location_is_approximate` = `true` or `false`
- `priority_score` = mapped from AI priority (CRITICAL→4, etc.)

**Step 4:** Tap **OK** on **Report Submitted**.

**Screen shows:** Dialog closes; citizen list / map updates when store refreshes.

**Step 5:** Log out; log in as **JE** for **`Central`** (`je.central@smcsolapur.gov.in`).

**Screen shows:** JE **My Work Desk** — the new complaint appears under **new / open** flows because `ward_zone` **Ward Pending** is treated as visible to JE (`pending` in `wardZone`).

**Supabase (JE visibility):** same row; `current_handler` should remain **`JE`** for new reports.

---

## SCRIPT B — JE verifies and assigns

**Goal:** Move complaint from **Open** toward **InProgress** / **PendingCEApproval** depending on path. The **full** verification + repair proof + SSIM + CE handoff is **one** screen: **`VerifyComplaintScreen`**.

**Step 1:** Log in as **Junior Engineer** (`je.central@smcsolapur.gov.in`).

**Screen shows:** Map + list; **My Work Desk** with counts.

**Step 2:** Open the complaint from Script A (from list or map).

**Screen shows:** Detail with images, SLA timer, **Verify** and **Escalate** for **`Open`** complaints.

**Step 3:** Tap **Verify**.

**Screen shows:** **`VerifyComplaintScreen`** — remarks, **contractor** or **work gang** pickers, **damage / risk / traffic / action** dropdowns, **field photos** (camera/gallery).

**Step 4:** Add **at least two** field photos (required by validation). Select **contractor** (or work gang). Fill required dropdowns.

**Screen shows:** Form valid for submit.

**Step 5:** Tap **Submit** on the verify screen.

**What happens in code:**

- Images upload to storage; **before** = existing citizen images; **after** = new field photos.
- `FlaskAiService.verifyRepair(before, after)` runs SSIM.
- If **`verdict == REPAIR_VERIFIED`**: `ComplaintStore.submitForCEAuthorization` with **`status: PendingCEApproval`**.
- If verification **times out** or **throws**: SnackBar error; **no** status advance to CE.

**Supabase after successful SSIM + pass:**

- `status` = **`PendingCEApproval`**
- `current_handler` moves to **`CE`** (see `submitForCEAuthorization` in `complaint_store.dart`)
- `ssim_score`, `verification_status`, `before_images` / `after_images` updated per service
- `assigned_to` / `assigned_party_type` set from the form

**If SSIM fails or verdict is not repair verified:** status may **not** be set to `PendingCEApproval` (only added when `isRepairVerified`).

**Separate “Assign contractor”** from the JE card (without full verify): `assignComplaint` sets **`InProgress`** and assignment fields — use if you only test assignment without SSIM.

**Console (verify):** Flask `/verify-repair` response drives SSIM/verdict (check Flask logs).

---

## SCRIPT C — Contractor vs CE (actual app behavior)

**Important:** In the **current codebase**, **SSIM repair verification** and **Pending CE approval** are triggered from **`VerifyComplaintScreen`**, opened from the **Junior Engineer** complaint detail (**Verify** button), **not** from the contractor dashboard.

**Contractor dashboard** (`contractor_dashboard.dart`):

- Shows **assigned** complaints (`getContractorComplaints` — `InProgress` / etc.).
- Has a **stub** “Verify” dialog that only shows a SnackBar — **does not** call Flask SSIM or update Supabase.

**Therefore, use two sub-paths for demos:**

### C1 — “Real” SSIM + CE approval (recommended)

**Step 1:** Complete **Script B** until status is **`PendingCEApproval`**.

**Step 2:** Log in as **Chief Engineer** (`ce@smcsolapur.gov.in` or seed CE).

**Screen shows:** **Escalated** / **Pending authorization** style cards from `ceEscalatedComplaints()` (complaints with `status == 'PendingCEApproval'`).

**Step 3:** Open the complaint; use the **Approve / authorize** (wording in UI) **when status is `PendingCEApproval`**.

**Code:** `ComplaintStore.authorizeComplaint` → **`status: Resolved`** in `complaint_service.dart`.

**Supabase after:**

```sql
SELECT id, status, last_update
FROM complaints
WHERE id = '<complaint_id>';
```

**Expected:** `status` = **`Resolved`**.

**Step 4:** Log in as **citizen** again.

**Screen shows:** Complaint in **My complaints** as **Resolved** (or equivalent label from `status` mapping).

### C2 — Contractor “field view” only (no SSIM)

**Step 1:** Log in as **contractor** (`contractor1@smcsolapur.gov.in`).

**Screen shows:** Assigned **InProgress** work from `getContractorComplaints`.

**Step 2:** Open an assigned complaint; use **before/after** toggles if present in the card UI.

**Screen shows:** Read-only / narrative evidence; **no** SSIM submit here.

**Pass/fail SSIM:** To demo **same photo fail** vs **different surface pass**, use **JE → Verify** with two different after images or duplicate after — behavior is controlled by **`verdict == REPAIR_VERIFIED`** in `verify_complaint_screen.dart`.

---

## Quick verification SQL snippets

**Latest complaint row:**

```sql
SELECT id, status, ward_zone, severity_score, epdo_score, ai_source, current_handler
FROM complaints
ORDER BY created_at DESC
LIMIT 1;
```

**Pending CE queue:**

```sql
SELECT id, status, assigned_to, ssim_score, verification_status
FROM complaints
WHERE status = 'PendingCEApproval'
ORDER BY last_update DESC;
```

---

## When you paste Supabase results

The assistant will compare:

- `information_schema.columns` for `complaints` vs `schema.sql` / `migrate.sql`
- `auth.users` + `user_roles` join (if your schema uses `user_roles.email` or `user_id` — verify your actual table; seed uses `email` without `user_id` on `user_roles` in the snippet you provided)

and will list **missing columns**, **wrong types**, or **SQL patches** to align roles and wards.
