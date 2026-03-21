"""
Example Integration - How to use road_repair_model.py in your project
======================================================================

This file demonstrates the simplest way to integrate the road repair model
into another Python project.
"""

# ============================================================================
# METHOD 1: The Simplest Way (Recommended)
# ============================================================================

from road_repair_model import get_repair_recommendations

# Your inputs
your_image_path = "path/to/your/road_image.jpg"
your_latitude = 18.9068600
your_longitude = 73.9254634

# Get recommendations (ONE LINE!)
recommendations = get_repair_recommendations(
    image_paths=[your_image_path],
    latitude=your_latitude,
    longitude=your_longitude
)

# Use the results
print("=" * 60)
print("REPAIR RECOMMENDATIONS")
print("=" * 60)
print(f"Road Type: {recommendations['recommended_road_type']}")
print(f"Worker Type: {recommendations['worker_type']}")
print(f"Urgency: {recommendations['urgency']}")
print(f"Timeline: {recommendations['timeline']}")
print(f"Action: {recommendations['summary']}")
print("=" * 60)


# ============================================================================
# METHOD 2: More Detailed Results
# ============================================================================

from road_repair_model import RoadRepairRecommender

# Initialize
recommender = RoadRepairRecommender()

# Analyze with full details
result = recommender.analyze_and_recommend(
    image_paths=[your_image_path],
    latitude=your_latitude,
    longitude=your_longitude
)

# Access everything
print("\nCOMPLETE ANALYSIS:")
print(f"Location: {result['input']['latitude']}, {result['input']['longitude']}")
print(f"Potholes Found: {result['analysis_summary']['total_potholes_detected']}")
print(f"Severity Score: {result['analysis_summary']['average_severity_score']}/10")
print(f"\nRecommendations:")
recs = result['repair_recommendations']
print(f"  → Use {recs['recommended_road_type']} material")
print(f"  → Deploy {recs['worker_type']}")
print(f"  → Urgency: {recs['urgency']}")
print(f"  → Timeline: {recs['timeline']}")
print(f"  → {recs['summary']}")


# ============================================================================
# METHOD 3: Multiple Images at Once
# ============================================================================

multiple_images = [
    "road_image_1.jpg",
    "road_image_2.jpg",
    "road_image_3.jpg"
]

result = recommender.analyze_and_recommend(
    image_paths=multiple_images,
    latitude=your_latitude,
    longitude=your_longitude
)

print(f"\nBatch Analysis of {len(multiple_images)} images:")
print(f"Total Potholes: {result['analysis_summary']['total_potholes_detected']}")
print(f"Average Severity: {result['analysis_summary']['average_severity_score']}/10")
print(f"Recommendation: {result['repair_recommendations']['summary']}")


# ============================================================================
# METHOD 4: Error Handling for Production
# ============================================================================

def safe_get_recommendations(image_path, lat, lng):
    """Safely get recommendations with error handling."""
    try:
        recs = get_repair_recommendations([image_path], lat, lng)
        
        if recs:
            return {
                'success': True,
                'data': recs
            }
        else:
            return {
                'success': False,
                'error': 'No recommendations generated'
            }
            
    except FileNotFoundError as e:
        return {
            'success': False,
            'error': f'Image not found: {str(e)}'
        }
    except ValueError as e:
        return {
            'success': False,
            'error': f'Invalid input: {str(e)}'
        }
    except Exception as e:
        return {
            'success': False,
            'error': f'Analysis failed: {str(e)}'
        }

# Use it
result = safe_get_recommendations(your_image_path, your_latitude, your_longitude)

if result['success']:
    print(f"\n✓ Success! {result['data']['summary']}")
else:
    print(f"\n✗ Error: {result['error']}")


# ============================================================================
# THAT'S IT! Just pick the method that works best for your project.
# ============================================================================

# Method 1 is perfect for most cases - just one function call!
# Method 2 gives you more control and detailed results
# Method 3 for batch processing
# Method 4 for production systems with error handling
