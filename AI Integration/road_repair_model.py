"""
Road Repair Recommendation Model
=================================
A standalone API-compatible model for generating road repair recommendations
based on pothole detection and location analysis.

Integration:
    - Input: Image file(s) + GPS coordinates (latitude, longitude)
    - Output: Repair recommendations (road type, worker type, urgency, timeline)

Author: Pothole Detection System
Version: 1.0.0
"""

import requests
import base64
import os
from typing import Dict, List, Optional, Union
from PIL import Image, ImageDraw, ImageFont
from datetime import datetime
from dotenv import load_dotenv

# Load environment from project root so API keys are not hardcoded
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))


class RoadRepairRecommender:
    """
    A class to generate road repair recommendations based on AI-powered
    pothole detection and location analysis.
    """
    
    def __init__(
        self,
        roboflow_api_key: str = os.getenv('ROBOFLOW_API_KEY', ''),
        mapbox_api_key: str = os.getenv("MAPBOX_ACCESS_TOKEN", ""),
        roboflow_model_id: str = "pothole-detection-gv5e7/3"
    ):
        """
        Initialize the RoadRepairRecommender with API keys.
        
        Args:
            roboflow_api_key: API key for Roboflow computer vision
            mapbox_api_key: API key for Mapbox geocoding
            roboflow_model_id: Model ID for pothole detection
        """
        self.roboflow_api_key = roboflow_api_key
        self.mapbox_api_key = mapbox_api_key
        self.roboflow_model_id = roboflow_model_id
        self.roboflow_url = "https://serverless.roboflow.com"
        
    def analyze_and_recommend(
        self,
        image_paths: Union[str, List[str]],
        latitude: float,
        longitude: float,
        save_visualizations: bool = False,
        visualization_dir: str = "visualizations"
    ) -> Dict:
        """
        Main method to analyze road images and generate repair recommendations.
        
        Args:
            image_paths: Single image path or list of image paths
            latitude: GPS latitude coordinate
            longitude: GPS longitude coordinate
            save_visualizations: Whether to save visualization images
            visualization_dir: Directory to save visualizations
            
        Returns:
            Dictionary containing repair recommendations and analysis results
        """
        # Handle single image path
        if isinstance(image_paths, str):
            image_paths = [image_paths]
        
        # Validate inputs
        self._validate_inputs(image_paths, latitude, longitude)
        
        # Auto-detect location parameters
        location_params = self._detect_location_parameters(latitude, longitude)
        
        # Analyze each image
        image_results = []
        total_severity = 0
        
        for idx, image_path in enumerate(image_paths):
            result = self._analyze_image(
                image_path=image_path,
                location_params=location_params,
                save_viz=save_visualizations,
                viz_dir=visualization_dir
            )
            image_results.append(result)
            total_severity += result['severity_score']
        
        # Calculate average severity
        avg_severity = total_severity / len(image_results) if image_results else 0
        
        # Generate repair recommendations
        repair_recommendations = self.generate_repair_recommendations(
            severity_score=avg_severity,
            road_type=location_params['road_type'],
            road_classification=location_params['road_classification'],
            traffic_level=location_params['traffic_level'],
            location_type=location_params['location_type']
        )
        
        # Compile final result
        result = {
            'success': True,
            'input': {
                'image_count': len(image_paths),
                'latitude': latitude,
                'longitude': longitude
            },
            'location_parameters': location_params,
            'analysis_summary': {
                'total_images': len(image_paths),
                'average_severity_score': round(avg_severity, 2),
                'total_potholes_detected': sum(r['total_potholes'] for r in image_results)
            },
            'repair_recommendations': repair_recommendations,
            'image_details': image_results if len(image_paths) > 1 else None
        }
        
        return result
    
    def _validate_inputs(
        self,
        image_paths: List[str],
        latitude: float,
        longitude: float
    ) -> None:
        """Validate input parameters."""
        # Validate image paths
        for path in image_paths:
            if not os.path.exists(path):
                raise FileNotFoundError(f"Image not found: {path}")
            if not path.lower().endswith(('.jpg', '.jpeg', '.png')):
                raise ValueError(f"Unsupported image format: {path}")
        
        # Validate coordinates
        if not (-90 <= latitude <= 90):
            raise ValueError(f"Invalid latitude: {latitude}. Must be between -90 and 90.")
        if not (-180 <= longitude <= 180):
            raise ValueError(f"Invalid longitude: {longitude}. Must be between -180 and 180.")
    
    def _detect_location_parameters(
        self,
        latitude: float,
        longitude: float
    ) -> Dict:
        """
        Detect road parameters from GPS coordinates using Mapbox API.
        
        Returns:
            Dictionary with detected road parameters
        """
        # Default values
        params = {
            'road_type': 'asphalt',
            'road_classification': 'arterial',
            'traffic_level': 'medium',
            'location_type': 'urban'
        }
        
        try:
            # Call Mapbox Geocoding API
            response = requests.get(
                f"https://api.mapbox.com/geocoding/v5/mapbox.places/{longitude},{latitude}.json",
                params={'access_token': self.mapbox_api_key}
            )
            
            if response.status_code == 200:
                geocode_data = response.json()
                
                if geocode_data.get('features'):
                    # Find most specific feature
                    place_data = None
                    priority_order = ['locality', 'place', 'district', 'postcode', 'region']
                    
                    for place_type in priority_order:
                        feature = next(
                            (f for f in geocode_data['features'] 
                             if place_type in f.get('place_type', [])),
                            None
                        )
                        if feature:
                            place_data = feature
                            break
                    
                    if not place_data:
                        place_data = geocode_data['features'][0]
                    
                    # Extract information
                    address_text = place_data.get('place_name', '').lower()
                    context = place_data.get('context', [])
                    
                    # Extract context names
                    locality_name = next(
                        (c.get('text', '').lower() for c in context 
                         if c.get('place_type') == 'locality'), ''
                    )
                    place_name = next(
                        (c.get('text', '').lower() for c in context 
                         if c.get('place_type') == 'place'), ''
                    )
                    district_name = next(
                        (c.get('text', '').lower() for c in context 
                         if c.get('place_type') == 'district'), ''
                    )
                    
                    all_text = f"{address_text} {locality_name} {place_name} {district_name}"
                    
                    # Determine location type
                    urban_indicators = [
                        'pune', 'mumbai', 'delhi', 'bangalore', 'chennai', 
                        'kolkata', 'hyderabad', 'ahmedabad', 'solapur', 'city', 'downtown',
                        'metropolitan', 'urban'
                    ]
                    rural_indicators = [
                        'rural', 'county', 'township', 'unincorporated', 
                        'village', 'hamlet'
                    ]
                    
                    if any(word in all_text for word in rural_indicators):
                        params['location_type'] = 'rural'
                    elif any(word in all_text for word in urban_indicators):
                        params['location_type'] = 'urban'
                    else:
                        params['location_type'] = 'urban' if len(context) >= 4 else 'rural'
                    
                    # Infer road characteristics
                    interstate_indicators = ['interstate', 'i-', 'expressway', 'nh-', 'national highway']
                    highway_indicators = ['highway', 'us-', 'state route', 'sh-', 'main road']
                    arterial_indicators = ['avenue', 'boulevard', 'street', 'road', 'mg road', 'fc road']
                    local_indicators = ['lane', 'drive', 'court', 'alley', 'nagar', 'colony', 'society']
                    
                    if any(term in all_text for term in interstate_indicators):
                        params['road_classification'] = 'interstate'
                        params['traffic_level'] = 'very_high'
                    elif any(term in all_text for term in highway_indicators):
                        params['road_classification'] = 'highway'
                        params['traffic_level'] = 'high'
                    elif any(term in all_text for term in arterial_indicators):
                        params['road_classification'] = 'arterial'
                        params['traffic_level'] = 'high' if params['location_type'] == 'urban' else 'medium'
                    elif any(term in all_text for term in local_indicators):
                        params['road_classification'] = 'local'
                        params['traffic_level'] = 'medium' if params['location_type'] == 'urban' else 'low'
                    else:
                        if params['location_type'] == 'urban':
                            params['road_classification'] = 'arterial'
                            params['traffic_level'] = 'medium'
                        else:
                            params['road_classification'] = 'local'
                            params['traffic_level'] = 'low'
                            
        except Exception as e:
            print(f"Warning: Could not detect location parameters: {e}")
            # Use defaults
        
        return params
    
    def _analyze_image(
        self,
        image_path: str,
        location_params: Dict,
        save_viz: bool = False,
        viz_dir: str = "visualizations"
    ) -> Dict:
        """
        Analyze a single image for potholes.
        
        Returns:
            Dictionary with detection results and severity score
        """
        # Run pothole detection
        detections = self._detect_potholes(image_path)
        
        # Calculate severity score
        severity_score = self.calculate_severity_score(
            detections=detections,
            road_type=location_params['road_type'],
            road_classification=location_params['road_classification'],
            traffic_level=location_params['traffic_level'],
            location_type=location_params['location_type']
        )
        
        # Create visualization if requested
        visualization_path = None
        if save_viz:
            visualization_path = self._create_visualization(
                image_path=image_path,
                detections=detections,
                output_dir=viz_dir
            )
        
        return {
            'image_path': image_path,
            'filename': os.path.basename(image_path),
            'total_potholes': len(detections),
            'detections': detections,
            'severity_score': severity_score,
            'visualization_path': visualization_path
        }
    
    def _detect_potholes(self, image_path: str) -> List[Dict]:
        """
        Detect potholes in an image using Roboflow API.
        
        Returns:
            List of detection dictionaries
        """
        try:
            with open(image_path, 'rb') as f:
                files_upload = {'file': (os.path.basename(image_path), f, 'image/jpeg')}
                
                response = requests.post(
                    f"{self.roboflow_url}/{self.roboflow_model_id}",
                    params={"api_key": self.roboflow_api_key},
                    files=files_upload
                )
            
            if response.status_code != 200:
                print(f"Warning: API returned status {response.status_code}")
                return []
            
            result = response.json()
            detections = []
            
            if 'predictions' in result:
                predictions = result['predictions']
                
                for idx, prediction in enumerate(predictions, 1):
                    detection = {
                        'id': idx,
                        'confidence': round(prediction.get('confidence', 0) * 100, 2),
                        'x_center': prediction.get('x', 0),
                        'y_center': prediction.get('y', 0),
                        'width': prediction.get('width', 0),
                        'height': prediction.get('height', 0),
                        'class': prediction.get('class', 'pothole')
                    }
                    detections.append(detection)
            
            return detections
            
        except Exception as e:
            print(f"Error detecting potholes: {e}")
            return []
    
    def calculate_severity_score(
        self,
        detections: List[Dict],
        road_type: str,
        road_classification: str,
        traffic_level: str,
        location_type: str
    ) -> float:
        """
        Calculate road severity score based on weighted factors.
        
        Weights:
        - Pothole Size: 20%
        - Number of Potholes: 25%
        - Road Type: 25%
        - Road Classification: 10%
        - Traffic Patterns: 20%
        - Location Context: ±0.1 adjustment
        
        Returns:
            Severity score (0-10)
        """
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
        base_score = (
            size_weighted + 
            count_weighted + 
            road_type_weighted + 
            road_class_weighted + 
            traffic_weighted
        )
        
        # Factor 6: Location Context (Adjustment factor)
        location_adjustment = 0
        if location_type.lower() == 'rural':
            location_adjustment = -0.1
        elif location_type.lower() == 'urban':
            location_adjustment = 0.1
        
        final_score = base_score + (base_score * location_adjustment)
        final_score = max(0, min(10, final_score))
        
        return round(final_score, 2)
    
    def generate_repair_recommendations(
        self,
        severity_score: float,
        road_type: str,
        road_classification: str,
        traffic_level: str,
        location_type: str
    ) -> Dict:
        """
        Generate repair recommendations based on analysis results.
        
        Returns:
            Dictionary with repair recommendations
        """
        # Determine road material recommendation
        if location_type.lower() == 'urban' or traffic_level.lower() in ['high', 'very_high']:
            recommended_road_type = 'Premix'
            road_type_reason = 'Urban area / High traffic volume'
        else:
            recommended_road_type = 'Hotmix'
            road_type_reason = 'Rural area / Low traffic volume'
        
        # Determine worker type recommendation
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
        
        # Calculate urgency
        if severity_score >= 7:
            urgency = 'IMMEDIATE'
            timeline = '24-48 hours'
        elif severity_score >= 5:
            urgency = 'HIGH'
            timeline = '1-2 weeks'
        elif severity_score >= 3:
            urgency = 'MODERATE'
            timeline = '2-4 weeks'
        else:
            urgency = 'ROUTINE'
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
    
    def _create_visualization(
        self,
        image_path: str,
        detections: List[Dict],
        output_dir: str
    ) -> Optional[str]:
        """
        Create visualization with bounding boxes around detected potholes.
        
        Returns:
            Path to saved visualization image
        """
        try:
            # Create output directory
            os.makedirs(output_dir, exist_ok=True)
            
            # Open image
            img = Image.open(image_path)
            draw = ImageDraw.Draw(img)
            
            # Load font
            try:
                font = ImageFont.truetype("arial.ttf", 20)
            except:
                font = ImageFont.load_default()
            
            # Draw bounding boxes
            for detection in detections:
                x_center = detection['x_center']
                y_center = detection['y_center']
                width = detection['width']
                height = detection['height']
                
                x_min = int(x_center - width / 2)
                y_min = int(y_center - height / 2)
                x_max = int(x_center + width / 2)
                y_max = int(y_center + height / 2)
                
                # Draw rectangle
                draw.rectangle([x_min, y_min, x_max, y_max], outline='#00FF00', width=3)
                
                # Draw label
                label = f"#{detection['id']} {detection['confidence']}%"
                bbox = draw.textbbox((x_min, y_min - 25), label, font=font)
                draw.rectangle([bbox[0], bbox[1], bbox[2], bbox[3]], fill='#00FF00')
                draw.text((x_min, y_min - 25), label, fill='#000000', font=font)
            
            # Save visualization
            filename = f"viz_{os.path.basename(image_path)}"
            output_path = os.path.join(output_dir, filename)
            img.save(output_path)
            
            return output_path
            
        except Exception as e:
            print(f"Error creating visualization: {e}")
            return None


# Convenience function for quick integration
def get_repair_recommendations(
    image_paths: Union[str, List[str]],
    latitude: float,
    longitude: float
) -> Dict:
    """
    Quick function to get repair recommendations.
    
    Args:
        image_paths: Image file path(s)
        latitude: GPS latitude
        longitude: GPS longitude
        
    Returns:
        Dictionary with repair recommendations
    """
    recommender = RoadRepairRecommender()
    result = recommender.analyze_and_recommend(
        image_paths=image_paths,
        latitude=latitude,
        longitude=longitude
    )
    return result['repair_recommendations']


# Example usage
if __name__ == "__main__":
    # Example integration
    recommender = RoadRepairRecommender()
    
    # Your inputs
    images = ["road_image.jpg"]  # Replace with your image path
    lat = 18.9068600  # Replace with your latitude
    lng = 73.9254634  # Replace with your longitude
    
    # Get recommendations
    result = recommender.analyze_and_recommend(
        image_paths=images,
        latitude=lat,
        longitude=lng
    )
    
    # Print recommendations
    print("\n" + "="*60)
    print("🔧 ROAD REPAIR RECOMMENDATIONS")
    print("="*60)
    
    recs = result['repair_recommendations']
    print(f"\nRecommended Road Type: {recs['recommended_road_type']}")
    print(f"Reason: {recs['road_type_reason']}")
    print(f"\nWorker Type: {recs['worker_type']}")
    print(f"Reason: {recs['worker_reason']}")
    print(f"\nUrgency: {recs['urgency']}")
    print(f"Timeline: {recs['timeline']}")
    print(f"\nSummary: {recs['summary']}")
    print("="*60)
