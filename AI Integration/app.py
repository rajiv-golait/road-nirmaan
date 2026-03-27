from flask import Flask, render_template, request, jsonify, send_file
import requests
import base64
import os
import math
import hashlib
from datetime import datetime
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import cv2
from skimage.metrics import structural_similarity as ssim
from dotenv import load_dotenv

from flask_cors import CORS

# Load .env from project root (one level up from AI Integration/)
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter Web requests

# Configure upload folder
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Create uploads directory if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Roboflow / Mapbox — loaded from project root .env (see ROBOFLOW_* / MAPBOX_ACCESS_TOKEN)
API_KEY = os.getenv('ROBOFLOW_API_KEY', '')
API_URL = os.getenv('ROBOFLOW_API_URL', 'https://serverless.roboflow.com')
MODEL_ID = os.getenv('ROBOFLOW_MODEL_ID', 'pothole-detection-gv5e7/3')
MAPBOX_API_KEY = os.getenv('MAPBOX_ACCESS_TOKEN', '')

if not API_KEY:
    raise RuntimeError(
        'ROBOFLOW_API_KEY not set in .env. Cannot start without it.'
    )


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'ok',
        'roboflow_key_set': bool(API_KEY),
        'mapbox_key_set': bool(MAPBOX_API_KEY),
    })


def haversine(lat1, lon1, lat2, lon2):
    radius_m = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * radius_m * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def prepare_image_for_roboflow(filepath, max_dimension=1280, quality=82):
    """
    Downscale and normalize images before sending them to Roboflow.
    This reduces upload/inference time and avoids unnecessary large payloads.
    """
    with Image.open(filepath) as img:
        if img.mode not in ('RGB', 'L'):
            img = img.convert('RGB')
        else:
            img = img.copy()

        width, height = img.size
        longest_edge = max(width, height)
        if longest_edge > max_dimension:
            scale = max_dimension / float(longest_edge)
            img = img.resize(
                (max(1, int(width * scale)), max(1, int(height * scale))),
                Image.Resampling.LANCZOS,
            )

        optimized_path = os.path.splitext(filepath)[0] + '_rf.jpg'
        img.save(optimized_path, format='JPEG', quality=quality, optimize=True)
        return optimized_path

def calculate_severity_score(detections, road_type, road_classification, traffic_level, location_type):
    """
    Calculate road severity score based on weighted factors:
    - Pothole Size: 20% weight
    - Number of Potholes: 25% weight
    - Road Type: 25% weight
    - Road Classification: 10% weight
    - Traffic Patterns: 20% weight
    - Location Context: Adjustment factor (±0.1)
    """
    if not detections:
        return 0.0

    # Factor 1: Pothole Size (20% weight)
    size_score = 0
    if detections:
        total_area = sum(d['width'] * d['height'] for d in detections)
        avg_area = total_area / len(detections)
        
        if avg_area > 50000:
            size_score = 10
        elif avg_area > 30000:
            size_score = 8
        elif avg_area > 15000:
            size_score = 6
        elif avg_area > 5000:
            size_score = 4
        else:
            size_score = 2
    
    size_weighted = size_score * 0.20
    
    # Factor 2: Number of Potholes (25% weight)
    count = len(detections)
    if count >= 10:
        count_score = 10
    elif count >= 7:
        count_score = 8
    elif count >= 5:
        count_score = 6
    elif count >= 3:
        count_score = 4
    elif count >= 1:
        count_score = 2
    else:
        count_score = 0
    
    count_weighted = count_score * 0.25
    
    # Factor 3: Road Type (25% weight)
    road_type_scores = {
        'concrete': 3,
        'asphalt': 5,
        'gravel': 7,
        'dirt': 9,
        'cobblestone': 6
    }
    road_type_score = road_type_scores.get(road_type.lower(), 5)
    road_type_weighted = road_type_score * 0.25
    
    # Factor 4: Road Classification (10% weight)
    road_class_scores = {
        'interstate': 2,
        'highway': 3,
        'arterial': 5,
        'collector': 6,
        'local': 7,
        'residential': 8
    }
    road_class_score = road_class_scores.get(road_classification.lower(), 5)
    road_class_weighted = road_class_score * 0.10
    
    # Factor 5: Traffic Patterns (20% weight)
    traffic_scores = {
        'very_low': 3,
        'low': 4,
        'medium': 6,
        'high': 8,
        'very_high': 10
    }
    traffic_score = traffic_scores.get(traffic_level.lower(), 6)
    traffic_weighted = traffic_score * 0.20
    
    # Base score
    base_score = size_weighted + count_weighted + road_type_weighted + road_class_weighted + traffic_weighted
    
    # Factor 6: Location Context (Adjustment factor)
    location_adjustment = 0
    if location_type.lower() == 'rural':
        location_adjustment = -0.1
    elif location_type.lower() == 'urban':
        location_adjustment = 0.1
    
    final_score = base_score + (base_score * location_adjustment)
    final_score = max(0, min(10, final_score))
    
    return round(final_score, 2)

def calculate_epdo_score(severity_score, road_classification, traffic_level, rainfall_risk, proximity_score):
    if severity_score <= 0:
        return 0.0

    # S_AI: normalize severity (0-10) to (0-1)
    s_ai = severity_score / 10.0

    # T_OSM: map road_classification to traffic weight
    osm_weights = {
        'interstate': 1.0, 'highway': 0.85,
        'arterial': 0.65, 'collector': 0.45,
        'local': 0.25, 'residential': 0.15
    }
    t_osm = osm_weights.get(road_classification.lower(), 0.5)

    # R_historical: map rainfall risk (hardcode Solapur zones)
    # Solapur avg: 550mm/year, monsoon risk = medium
    r_hist = {'high': 1.0, 'medium': 0.6, 'low': 0.3}.get(
        str(rainfall_risk).lower(), 0.6
    )

    # C_proximity: 1.0 if near hospital/fire station, else 0.2
    try:
        c_prox = float(proximity_score)
    except (ValueError, TypeError):
        c_prox = 0.2

    epdo = (0.40 * s_ai) + (0.30 * t_osm) + \
           (0.15 * r_hist) + (0.15 * c_prox)
    return round(epdo * 10, 2)  # scale to 0-10

def generate_repair_recommendations(severity_score, road_type, road_classification, traffic_level, location_type):
    """
    Generate repair recommendations based on analysis results:
    - Road type to build (Premix for urban/high traffic, Hotmix for rural/low traffic)
    - Worker type (Contractor for big tasks, Work gang for short tasks)
    """
    if severity_score <= 0:
        return {
            'recommended_road_type': 'Not Required',
            'road_type_reason': 'No potholes detected by Roboflow analysis',
            'worker_type': 'Not Required',
            'worker_reason': 'No repair crew needed because no potholes were detected',
            'urgency': 'NONE',
            'timeline': 'No action required',
            'summary': 'No potholes detected. No repair action recommended.'
        }

    # Determine road material recommendation
    if location_type.lower() == 'urban' or traffic_level.lower() in ['high', 'very_high']:
        recommended_road_type = 'Premix'
        road_type_reason = 'Urban area / High traffic volume'
    else:
        recommended_road_type = 'Hotmix'
        road_type_reason = 'Rural area / Low traffic volume'
    
    # Determine worker type recommendation
    total_potholes = 0  # Will be passed from detections
    
    # Big task criteria:
    # - Severity >= 7 (CRITICAL)
    # - OR severity >= 5 (HIGH) with high/very_high traffic
    # - OR interstate/highway classification
    if severity_score >= 7:
        worker_type = 'Contractor'
        worker_reason = 'Critical damage requiring major reconstruction'
    elif severity_score >= 5 and traffic_level.lower() in ['high', 'very_high']:
        worker_type = 'Contractor'
        worker_reason = 'High traffic area requires professional equipment and faster completion'
    elif road_classification.lower() in ['interstate', 'highway']:
        worker_type = 'Contractor'
        worker_reason = 'Major road classification requires specialized contractor'
    elif severity_score >= 5:
        worker_type = 'Contractor'
        worker_reason = 'Significant damage beyond routine maintenance scope'
    else:
        worker_type = 'Work Gang'
        worker_reason = 'Routine maintenance suitable for municipal work crew'
    
    # Additional recommendations
    urgency = 'IMMEDIATE' if severity_score >= 7 else 'HIGH' if severity_score >= 5 else 'MODERATE' if severity_score >= 3 else 'ROUTINE'
    
    # Estimated timeline
    if severity_score >= 7:
        timeline = '24-48 hours'
    elif severity_score >= 5:
        timeline = '1-2 weeks'
    elif severity_score >= 3:
        timeline = '2-4 weeks'
    else:
        timeline = '1-3 months (scheduled maintenance)'
    
    return {
        'recommended_road_type': recommended_road_type,
        'road_type_reason': road_type_reason,
        'worker_type': worker_type,
        'worker_reason': worker_reason,
        'urgency': urgency,
        'timeline': timeline,
        'summary': f"{urgency} priority repair needed. Use {recommended_road_type} material with {worker_type} deployment."
    }

@app.route('/')
def index():
    return render_template('index.html', mapbox_key=MAPBOX_API_KEY)

@app.route('/detect', methods=['POST'])
def detect():
    try:
        # Check if files are present in request
        if 'images' not in request.files:
            return jsonify({'error': 'No image files provided'}), 400
        
        files = request.files.getlist('images')
        
        # Filter out empty filenames
        files = [f for f in files if f.filename != '']
        
        if len(files) == 0:
            return jsonify({'error': 'No files selected'}), 400
        
        # Get additional data from form
        latitude = request.form.get('latitude', None)
        longitude = request.form.get('longitude', None)
        
        # Auto-detect parameters from coordinates if provided
        road_type = 'asphalt'  # default
        road_classification = 'highway'  # default
        traffic_level = 'medium'  # default
        location_type = 'urban'  # default
        
        if latitude and longitude:
            try:
                # Fetch location data from Mapbox Geocoding API (without type filter)
                geocode_response = requests.get(
                    f"https://api.mapbox.com/geocoding/v5/mapbox.places/{longitude},{latitude}.json",
                    params={
                        'access_token': MAPBOX_API_KEY
                    }
                )
                
                if geocode_response.status_code == 200:
                    geocode_data = geocode_response.json()
                    
                    # Analyze location context from geocoding results
                    if geocode_data.get('features'):
                        # Find the most specific feature (locality > place > district)
                        place_data = None
                        priority_order = ['locality', 'place', 'district', 'postcode', 'region']
                        for place_type in priority_order:
                            feature = next((f for f in geocode_data['features'] if place_type in f.get('place_type', [])), None)
                            if feature:
                                place_data = feature
                                break
                        
                        if not place_data:
                            place_data = geocode_data['features'][0]
                        
                        address_text = place_data.get('place_name', '').lower()
                        context = place_data.get('context', [])
                        
                        # Extract context names
                        locality_name = next((c.get('text', '').lower() for c in context if c.get('place_type') == 'locality'), '')
                        place_name = next((c.get('text', '').lower() for c in context if c.get('place_type') == 'place'), '')
                        district_name = next((c.get('text', '').lower() for c in context if c.get('place_type') == 'district'), '')
                        
                        all_text = f"{address_text} {locality_name} {place_name} {district_name}"
                        
                        # Determine location type (urban/rural) from address density
                        urban_indicators = ['pune', 'mumbai', 'delhi', 'bangalore', 'chennai', 'kolkata', 
                                          'hyderabad', 'ahmedabad', 'city', 'downtown', 'metropolitan', 'urban']
                        rural_indicators = ['rural', 'county', 'township', 'unincorporated', 'village', 'hamlet']
                        
                        if any(word in all_text for word in rural_indicators):
                            location_type = 'rural'
                        elif any(word in all_text for word in urban_indicators):
                            location_type = 'urban'
                        else:
                            # Heuristic: multiple administrative levels suggests urban/suburban
                            location_type = 'urban' if len(context) >= 4 else 'rural'
                        
                        # Infer road characteristics
                        interstate_indicators = ['interstate', 'i-', 'expressway', 'nh-', 'national highway']
                        highway_indicators = ['highway', 'us-', 'state route', 'sh-', 'main road']
                        arterial_indicators = ['avenue', 'boulevard', 'street', 'road', 'mg road', 'fc road']
                        local_indicators = ['lane', 'drive', 'court', 'alley', 'nagar', 'colony', 'society']
                        
                        if any(term in all_text for term in interstate_indicators):
                            road_classification = 'interstate'
                            traffic_level = 'very_high'
                        elif any(term in all_text for term in highway_indicators):
                            road_classification = 'highway'
                            traffic_level = 'high'
                        elif any(term in all_text for term in arterial_indicators):
                            road_classification = 'arterial'
                            traffic_level = 'high' if location_type == 'urban' else 'medium'
                        elif any(term in all_text for term in local_indicators):
                            road_classification = 'local'
                            traffic_level = 'medium' if location_type == 'urban' else 'low'
                        else:
                            # Default based on location type
                            if location_type == 'urban':
                                road_classification = 'arterial'
                                traffic_level = 'medium'
                            else:
                                road_classification = 'local'
                                traffic_level = 'low'
                                
            except Exception as e:
                print(f"Could not fetch location data: {e}")
                # Use defaults if geocoding fails
        
        # Process each image
        all_results = []
        total_severity_score = 0
        
        for file_idx, file in enumerate(files, 1):
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
            filename = f"{timestamp}_{file.filename}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            
            # Run inference using Roboflow Serverless API
            with open(filepath, 'rb') as f:
                files_upload = {'file': (os.path.basename(filepath), f, 'image/jpeg')}
                
                response = requests.post(
                    f"{API_URL}/{MODEL_ID}",
                    params={"api_key": API_KEY},
                    files=files_upload
                )
            
            print(f"Image {file_idx}/{len(files)} - Response status: {response.status_code}")
            
            if response.status_code != 200:
                raise Exception(f"API Error for {file.filename}: {response.status_code} - {response.text}")
            
            result = response.json()
            
            # Process results
            detections = []
            if 'predictions' in result:
                predictions = result['predictions']
                
                # Check for normalized coordinates
                img = Image.open(filepath)
                img_w, img_h = img.size
                is_normalized = False
                if predictions:
                    is_normalized = all(
                        p.get('x',0) <= 1.0 and p.get('y',0) <= 1.0
                        for p in predictions[:3]
                    )
                
                for idx, prediction in enumerate(predictions, 1):
                    x_c = prediction.get('x', 0)
                    y_c = prediction.get('y', 0)
                    w = prediction.get('width', 0)
                    h = prediction.get('height', 0)
                    
                    if is_normalized:
                        x_c *= img_w
                        y_c *= img_h
                        w *= img_w
                        h *= img_h
                        
                    detection = {
                        'id': idx,
                        'confidence': round(prediction.get('confidence', 0) * 100, 2),
                        'x_center': x_c,
                        'y_center': y_c,
                        'width': w,
                        'height': h,
                        'class': prediction.get('class', 'pothole')
                    }
                    detections.append(detection)
            
            # Calculate severity score based on weighted scoring system
            severity_score = calculate_severity_score(
                detections=detections,
                road_type=road_type,
                road_classification=road_classification,
                traffic_level=traffic_level,
                location_type=location_type
            )
            
            total_severity_score += severity_score
            
            # Create visualization with bounding boxes
            vis_filename = f"vis_{filename}"
            vis_path = os.path.join(app.config['UPLOAD_FOLDER'], vis_filename)
            
            # Open image and draw on it
            img = Image.open(filepath)
            draw = ImageDraw.Draw(img)
            
            # Try to load a font, fall back to default if not available
            try:
                font = ImageFont.truetype("arial.ttf", 20)
            except:
                font = ImageFont.load_default()
            
            # Draw bounding boxes for each detection
            for detection in detections:
                x_center = detection['x_center']
                y_center = detection['y_center']
                width = detection['width']
                height = detection['height']
                
                # Calculate box coordinates
                x_min = int(x_center - width / 2)
                y_min = int(y_center - height / 2)
                x_max = int(x_center + width / 2)
                y_max = int(y_center + height / 2)
                
                # Draw rectangle (green color)
                draw.rectangle([x_min, y_min, x_max, y_max], outline='#00FF00', width=3)
                
                # Create label text
                label = f"#{detection['id']} {detection['confidence']}%"
                
                # Draw label background
                bbox = draw.textbbox((x_min, y_min - 25), label, font=font)
                draw.rectangle([bbox[0], bbox[1], bbox[2], bbox[3]], fill='#00FF00')
                
                # Draw label text
                draw.text((x_min, y_min - 25), label, fill='#000000', font=font)
            
            # Save visualized image
            img.save(vis_path)
            
            # Prepare result for this image
            image_result = {
                'filename': file.filename,
                'image_path': filepath,
                'visualization_path': vis_path,
                'total_potholes': len(detections),
                'detections': detections,
                'severity_score': severity_score,
                'metadata': {
                    'road_type': road_type,
                    'road_classification': road_classification,
                    'traffic_level': traffic_level,
                    'location_type': location_type,
                    'latitude': latitude,
                    'longitude': longitude
                }
            }
            
            all_results.append(image_result)
        
        # Return all results
        avg_severity_score = total_severity_score / len(all_results) if all_results else 0
        
        # Determine priority level
        if avg_severity_score >= 7:
            priority = 'CRITICAL'
            priority_color = '#FF0000'
        elif avg_severity_score >= 5:
            priority = 'HIGH'
            priority_color = '#FFA500'
        elif avg_severity_score >= 3:
            priority = 'MEDIUM'
            priority_color = '#FFFF00'
        else:
            priority = 'LOW'
            priority_color = '#00FF00'
        
        # Generate repair recommendations
        repair_recommendations = generate_repair_recommendations(
            severity_score=avg_severity_score,
            road_type=road_type,
            road_classification=road_classification,
            traffic_level=traffic_level,
            location_type=location_type
        )
        epdo = calculate_epdo_score(
            avg_severity_score,
            road_classification,
            traffic_level,
            request.form.get('rainfall_risk', 'medium'),
            request.form.get('proximity_score', 0.2),
        )
        
        return jsonify({
            'success': True,
            'total_images': len(all_results),
            'results': all_results,
            'average_severity_score': round(avg_severity_score, 2),
            'epdo_score': epdo,
            'priority': priority,
            'priority_color': priority_color,
            'scoring_weights': {
                'pothole_size': '20%',
                'number_of_potholes': '25%',
                'road_type': '25%',
                'road_classification': '10%',
                'traffic_patterns': '20%',
                'location_context': 'Adjustment factor'
            },
            'repair_recommendations': repair_recommendations
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/detect-flutter', methods=['POST'])
def detect_flutter():
    try:
        if 'images' not in request.files:
            return jsonify({'error': 'No image files provided'}), 400
        
        files = request.files.getlist('images')
        files = [f for f in files if f.filename != '']
        if len(files) == 0:
            return jsonify({'error': 'No files selected'}), 400

        print(f'[DETECT] Received {len(files)} images')
            
        latitude = request.form.get('latitude', None)
        longitude = request.form.get('longitude', None)
        rainfall_risk = request.form.get('rainfall_risk', 'medium')
        proximity_score = request.form.get('proximity_score', 0.2)
        
        road_type = 'asphalt'
        road_classification = 'highway'
        traffic_level = 'medium'
        location_type = 'urban'
        
        # We reuse the logic from detect (could be abstracted, but keeping simple)
        if latitude and longitude:
            try:
                geocode_response = requests.get(
                    f"https://api.mapbox.com/geocoding/v5/mapbox.places/{longitude},{latitude}.json",
                    params={'access_token': MAPBOX_API_KEY}
                )
                if geocode_response.status_code == 200:
                    gc_data = geocode_response.json()
                    if gc_data.get('features'):
                        pd = next((f for f in gc_data['features'] if 'locality' in f.get('place_type', [])), gc_data['features'][0])
                        txt = pd.get('place_name', '').lower()
                        urban_inds = ['pune', 'mumbai', 'delhi', 'bangalore', 'chennai', 'kolkata', 'hyderabad', 'ahmedabad', 'city', 'downtown', 'metropolitan', 'urban', 'solapur']
                        location_type = 'urban' if any(w in txt for w in urban_inds) else 'rural'
                        
                        intr = ['interstate', 'i-', 'expressway', 'nh-', 'national highway']
                        hw = ['highway', 'us-', 'state route', 'sh-', 'main road']
                        art = ['avenue', 'boulevard', 'street', 'road', 'mg road', 'fc road']
                        
                        if any(t in txt for t in intr):
                            road_classification = 'interstate'
                            traffic_level = 'very_high'
                        elif any(t in txt for t in hw):
                            road_classification = 'highway'
                            traffic_level = 'high'
                        elif any(t in txt for t in art):
                            road_classification = 'arterial'
                            traffic_level = 'high' if location_type == 'urban' else 'medium'
                        else:
                            road_classification = 'local'
                            traffic_level = 'medium' if location_type == 'urban' else 'low'
            except Exception as e:
                print(f"Geocoding error: {e}")
        
        all_detections = []
        total_sev = 0
        total_pots = 0
        analyzed_files = 0
        
        for file in files:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
            filename = f"{timestamp}_{file.filename}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)
            inference_path = prepare_image_for_roboflow(filepath)
            
            print(f'[DETECT] Calling Roboflow: {MODEL_ID}')
            with open(inference_path, 'rb') as f:
                res = requests.post(
                    f"{API_URL}/{MODEL_ID}",
                    params={"api_key": API_KEY},
                    files={'file': (os.path.basename(inference_path), f, 'image/jpeg')}
                )
            print(f'[DETECT] Roboflow status: {res.status_code}')
            if res.status_code != 200:
                raise Exception(
                    f"Roboflow analysis failed for {file.filename}: "
                    f"{res.status_code} - {res.text}"
                )
            res_json = res.json()
            predictions = res_json.get('predictions', [])
            
            img = Image.open(inference_path)
            img_w, img_h = img.size
            is_normalized = False
            if predictions:
                is_normalized = all(p.get('x',0) <= 1.0 and p.get('y',0) <= 1.0 for p in predictions[:3])
                
            file_detections = []
            for idx, p in enumerate(predictions, 1):
                x_c, y_c, w, h = p.get('x',0), p.get('y',0), p.get('width',0), p.get('height',0)
                if is_normalized:
                    x_c *= img_w; y_c *= img_h; w *= img_w; h *= img_h
                
                d = {
                    'id': idx, 'confidence': round(p.get('confidence',0)*100, 2),
                    'x_center': x_c, 'y_center': y_c, 'width': w, 'height': h,
                    'class': p.get('class', 'pothole')
                }
                file_detections.append(d)
                all_detections.append({'id': len(all_detections)+1, 'confidence': d['confidence'], 'width': w, 'height': h})

            total_pots += len(file_detections)
            s_score = calculate_severity_score(file_detections, road_type, road_classification, traffic_level, location_type)
            total_sev += s_score
            analyzed_files += 1
            
        if analyzed_files == 0:
            raise Exception('Roboflow did not analyze any image successfully.')

        avg_sev = total_sev / analyzed_files
        epdo = calculate_epdo_score(avg_sev, road_classification, traffic_level, rainfall_risk, proximity_score)
        rep = generate_repair_recommendations(avg_sev, road_type, road_classification, traffic_level, location_type)
        
        if total_pots <= 0 or avg_sev <= 0:
            pri = 'NONE'
        else:
            pri = 'CRITICAL' if avg_sev >= 7 else 'HIGH' if avg_sev >= 5 else 'MEDIUM' if avg_sev >= 3 else 'LOW'

        print(f'[DETECT] Detections: {len(all_detections)}')
        print(f'[DETECT] Severity: {round(avg_sev, 2)}')
        print(f'[DETECT] EPDO: {epdo}')
        
        return jsonify({
            'success': True,
            'severity_score': round(avg_sev, 2),
            'epdo_score': epdo,
            'priority': pri,
            'total_potholes': total_pots,
            'repair_recommendations': rep,
            'detections': all_detections
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/check-duplicate', methods=['POST'])
def check_duplicate():
    try:
        payload = request.get_json(force=True, silent=True) or {}
        new_lat = float(payload.get('latitude'))
        new_lng = float(payload.get('longitude'))
        nearby = payload.get('nearby_complaints', [])
        dedup_radius_meters = 50

        closest = None
        for item in nearby:
            try:
                lat = float(item.get('lat'))
                lng = float(item.get('lng'))
            except (TypeError, ValueError):
                continue
            status = str(item.get('status', '')).lower()
            if status in ('resolved', 'closed'):
                continue
            dist = haversine(new_lat, new_lng, lat, lng)
            if dist <= dedup_radius_meters:
                if closest is None or dist < closest['distance_m']:
                    closest = {
                        'master_id': item.get('id'),
                        'distance_m': round(dist, 2),
                    }

        if closest and closest.get('master_id'):
            return jsonify({
                'is_duplicate': True,
                'master_id': closest['master_id'],
                'distance_m': closest['distance_m'],
            })
        return jsonify({'is_duplicate': False})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


@app.route('/verify-repair', methods=['POST'])
def verify_repair():
    try:
        if 'before_image' not in request.files or 'after_image' not in request.files:
            return jsonify({'error': 'before_image and after_image are required'}), 400

        before_file = request.files['before_image']
        after_file = request.files['after_image']
        complaint_id = request.form.get('complaint_id', '').strip()

        before_bytes = before_file.read()
        after_bytes = after_file.read()
        before_arr = np.frombuffer(before_bytes, np.uint8)
        after_arr = np.frombuffer(after_bytes, np.uint8)
        before_img = cv2.imdecode(before_arr, cv2.IMREAD_GRAYSCALE)
        after_img = cv2.imdecode(after_arr, cv2.IMREAD_GRAYSCALE)
        if before_img is None or after_img is None:
            return jsonify({'error': 'Invalid image bytes'}), 400

        if before_img.shape != after_img.shape:
            after_img = cv2.resize(after_img, (before_img.shape[1], before_img.shape[0]))

        score, _ = ssim(before_img, after_img, full=True)
        # Inverse SSIM logic: surface must change after repair
        passed = score < 0.75
        verification_hash = None
        if passed:
            hash_input = f"{complaint_id}:{round(float(score), 6)}:{datetime.utcnow().isoformat()}"
            verification_hash = hashlib.sha256(hash_input.encode('utf-8')).hexdigest()

        return jsonify({
            'success': True,
            'ssim_score': round(float(score), 4),
            'verdict': 'REPAIR_VERIFIED' if passed else 'REPAIR_REJECTED',
            'verification_hash': verification_hash,
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/display-image/<filename>')
def display_image(filename):
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    
    if os.path.exists(filepath):
        return send_file(filepath)
    else:
        return jsonify({'error': 'Image not found'}), 404

if __name__ == '__main__':
    app.run(debug=True, use_reloader=False, host='0.0.0.0', port=5000)
