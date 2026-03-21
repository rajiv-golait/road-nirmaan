import os, re, subprocess, sys

def find_files(exts, exclude_dirs):
    res = []
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if not any(ex in os.path.join(root, d) for ex in exclude_dirs)]
        for f in files:
            if any(f.endswith(ext) for ext in exts):
                res.append(os.path.join(root, f))
    return sorted(res)

files = find_files(['.dart', '.py', '.sql', '.env', '.yaml', '.json'], ['.dart_tool', 'build', '.gradle', '.git', 'windows', 'linux', 'macos'])

def grep(pattern, include_paths, exts):
    res = []
    regex = re.compile(pattern)
    for f in files:
        if not any(f.endswith(ext) for ext in exts): continue
        if not any(inc in f for inc in include_paths): continue
        try:
            with open(f, 'r', encoding='utf-8') as file:
                for i, line in enumerate(file, 1):
                    if regex.search(line):
                        res.append(f"{f}:{i}:{line.strip()}")
        except: pass
    return res

with open('audit_out.txt', 'w', encoding='utf-8') as out:
    out.write("STEP 0 - MAP THE CODEBASE FIRST\n")
    for f in files: out.write(f + "\n")
    lib_count = len([f for f in files if f.startswith('.\\lib\\') and f.endswith('.dart')])
    ai_count = len([f for f in files if '.\\AI Integration\\' in f and f.endswith('.py')])
    sup_count = len([f for f in files if '.\\supabase\\' in f])
    out.write(f"\nlib/ dart count: {lib_count}\n")
    out.write(f"AI Integration/ py count: {ai_count}\n")
    out.write(f"supabase/ files count: {sup_count}\n")

    out.write("\nSECTION A - FAKE DATA DETECTION\n")
    out.write("A1. Hardcoded coordinates:\n")
    for m in grep(r"17\.6868|75\.9074|17\.686|75\.907", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    out.write("\nA2. Hardcoded tokens:\n")
    for m in grep(r"YOUR_MAPBOX|YOUR_TOKEN|placeholder|REPLACE_ME|INSERT_KEY", ['.\\lib\\', '.\\AI Integration\\'], ['.dart', '.py', '.env']): out.write(m + "\n")
    
    out.write("\nA3. Mock data seeder usage:\n")
    for m in grep(r"MockDataSeeder|buildLocalMock|localMock|mock_data|seedIfEmpty", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    out.write("\nA4. Demo auth bypass:\n")
    for m in grep(r"'123'|testpassword|demoLogin|allowDemo|isValidDemo|authOk = true", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    out.write("\nA5. Hardcoded severity:\n")
    for m in grep(r"'High'|'Medium'|'Low'|'Critical'|\"High\"|\"Medium\"|\"Low\"", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    out.write("\nA6. Silent catch blocks:\n")
    for m in grep(r"catch \(_\)|catch \(e\) {}|catch \(_\) {}|} catch {", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    out.write("\nA7. LOCAL- IDs:\n")
    for m in grep(r"LOCAL-|local_id|localId|_upsertLocal|localOnly", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    out.write("\nA8. Fake AI service usage:\n")
    for m in grep(r"AiRecommendationService|ai_recommendation|_signalFrom|_filenameOf|_deriveLocation", ['.\\lib\\'], ['.dart']): out.write(m + "\n")

    out.write("\nSECTION B - REAL CONNECTIONS\n")
    out.write("B1. Supabase config:\n")
    for m in grep(r"supabase|SUPABASE_URL|SUPABASE_KEY|supabaseUrl|supabaseKey|anonKey", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    try:
        with open('.env', 'r') as f: out.write("\n.env contents:\n" + f.read() + "\n")
    except: out.write("NO .ENV FILE\n")
    
    out.write("\nB2. Flask URL in Flutter:\n")
    for m in grep(r"FLASK_URL|localhost:5000|10\.0\.2\.2|baseUrl|_baseUrl", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    
    out.write("\nB3. Roboflow config in Flask:\n")
    for m in grep(r"API_KEY|MODEL_ID|roboflow|serverless.roboflow", ['.\\AI Integration\\'], ['.py']): out.write(m + "\n")
    
    out.write("\nB4. Mapbox config:\n")
    for m in grep(r"mapbox|MAPBOX|mapboxToken|mapbox_token", ['.\\lib\\', '.\\AI Integration\\'], ['.dart', '.py']): out.write(m + "\n")

    out.write("\nSECTION D - DATABASE REALITY\n")
    out.write("D1. schema.sql:\n")
    sql_files = [f for f in files if f.endswith('.sql')]
    if sql_files:
        for f in sql_files: out.write(f + "\n")
    else: out.write("NO DATABASE SCHEMA IN REPO\n")

    out.write("\nD2. Tables:\n")
    for m in grep(r"\.from\('[^']+'\)", ['.\\lib\\'], ['.dart']): out.write(m + "\n")
    out.write("\nD3. Columns:\n")
    for m in grep(r"complaint\['[^']+'\]", ['.\\lib\\'], ['.dart']): out.write(m + "\n")

    out.write("\nD4. RLS policies:\n")
    rls_files = [f for f in files if "rls.sql" in f or "policies.sql" in f]
    if rls_files:
        for f in rls_files: out.write(f + "\n")
    else: out.write("NO RLS IN REPO\n")

    out.write("\nSECTION F - PYTHON DEPENDENCIES\n")
    out.write("F1. requirements.txt:\n")
    try:
        with open('AI Integration/requirements.txt', 'r') as f: out.write(f.read() + "\n")
    except: out.write("NO requirements.txt\n")

    out.write("\nF2. pip show:\n")
    try:
        pip_out = subprocess.check_output("cd \"AI Integration\" && uv pip show scikit-image opencv-python python-dotenv flask requests pillow", shell=True, text=True)
        out.write(pip_out + "\n")
    except Exception as e: out.write(f"pip show failed: {e}\n")

    out.write("\nSECTION G - FLUTTER DEPENDENCIES\n")
    out.write("G1. pubspec.yaml:\n")
    try:
        with open('pubspec.yaml', 'r') as f:
            for line in f:
                if any(p in line for p in ['http', 'supabase_flutter', 'geolocator', 'image_picker', 'flutter_map']):
                    out.write(line.strip() + "\n")
    except: pass

    out.write("\nG2. AppConfig constants:\n")
    try:
        with open('lib/utils/constants.dart', 'r') as f: out.write("constants.dart:\n" + f.read()[:500] + "\n")
    except: out.write("constants.dart not found\n")
