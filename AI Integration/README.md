# 🕳️ Advanced Pothole Detection & Road Quality Analysis System

Complete AI-powered road quality analysis system with **Mapbox integration** and **weighted severity scoring**.

## ✨ Features

### 🎯 Core Capabilities
- **Multiple Image Upload**: Drag & drop or select multiple road images at once
- **AI Pothole Detection**: Powered by Roboflow Computer Vision API
- **Weighted Severity Scoring**: Comprehensive road quality assessment
- **Mapbox Integration**: Geospatial visualization of pothole locations
- **Real-time Analysis**: Instant feedback with visual bounding boxes
- **Priority Classification**: LOW, MEDIUM, HIGH, CRITICAL based on severity

### 📊 Weighted Scoring System

The system calculates a severity score (0-10) using six weighted factors:

| Factor | Weight | Description |
|--------|--------|-------------|
| **Pothole Size** | 20% | Based on average area (width × height) of detected potholes |
| **Number of Potholes** | 25% | Count of potholes detected in the image |
| **Road Type** | 25% | Material type (concrete, asphalt, gravel, dirt, cobblestone) |
| **Road Classification** | 10% | Road category (interstate, highway, arterial, collector, local, residential) |
| **Traffic Patterns** | 20% | Traffic volume (very_low, low, medium, high, very_high) |
| **Location Context** | Adjustment | Urban (+0.1) or Rural (-0.1) adjustment factor |

### 🗺️ Mapbox Features
- Interactive map display
- Color-coded markers (Green/Yellow/Orange/Red by severity)
- Clickable popups with detailed information
- Multiple location support
- Real-time marker updates

## 🚀 Quick Start

### Prerequisites
- Python 3.8 or higher
- pip package manager
- Web browser (Chrome, Firefox, Edge)

### Installation

1. **Navigate to project directory**:
   ```bash
   cd "c:\SAMVED HACKATHON\AI Integration"
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the application**:
   ```bash
   python app.py
   ```

4. **Open your browser**:
   Navigate to `http://localhost:5000`

## 📖 How to Use

### Step 1: Upload Images
- **Drag & drop** multiple road images onto the upload area, OR
- **Click** to browse and select multiple files (Ctrl+Click or Shift+Click)

### Step 2: Configure Parameters
Fill in the road parameters:
- **Road Type**: Select the road material
- **Road Classification**: Choose road category
- **Traffic Level**: Estimate traffic volume
- **Location Type**: Urban or Rural
- **GPS Coordinates**: Enter latitude and longitude for map placement

### Step 3: Analyze
Click **"🔍 Analyze Road Quality"** button

### Step 4: View Results
The system displays:
- **Overall Priority Score** (0-10) with color coding
- **Scoring Breakdown** showing all weighted factors
- **Individual Image Results** with:
  - Visualized output with bounding boxes
  - Pothole count and severity score
  - Detailed detection information (ID, confidence, position, size)
- **Mapbox Map** with markers showing analyzed locations

## 🔧 Configuration

### Mapbox API Key
Set `YOUR_MAPBOX_TOKEN` in code or use env var. Do not commit real tokens.

### Roboflow API Key
Pre-configured in the application for pothole detection model.

## 📁 File Structure

```
AI Integration/
├── app.py                          # Flask backend with weighted scoring
├── requirements.txt                # Python dependencies
├── README.md                       # This file
├── templates/
│   └── index.html                 # Frontend with Mapbox integration
└── uploads/                        # Temporary storage for uploaded images
```

## 🎨 UI Components

### Upload Section
- Multi-file drag & drop interface
- Grid preview of selected images
- Image count display

### Parameters Section
- Dropdown menus for categorical variables
- Input fields for GPS coordinates
- Submit button with loading state

### Map Section
- Full Mapbox GL JS integration
- Navigation controls (zoom, pan)
- Color-coded severity markers
- Interactive popups

### Results Section
- Priority banner with overall score
- Weight breakdown cards
- Individual image result cards
- Detection detail cards with confidence scores

## 🎯 Scoring Algorithm Details

### Size Score Calculation
- > 50,000 pixels²: Score 10/10
- > 30,000 pixels²: Score 8/10
- > 15,000 pixels²: Score 6/10
- > 5,000 pixels²: Score 4/10
- Otherwise: Score 2/10

### Count Score Calculation
- ≥ 10 potholes: Score 10/10
- ≥ 7 potholes: Score 8/10
- ≥ 5 potholes: Score 6/10
- ≥ 3 potholes: Score 4/10
- ≥ 1 pothole: Score 2/10
- 0 potholes: Score 0/10

### Priority Levels
- **CRITICAL** (≥ 7.0): Red - Immediate attention required
- **HIGH** (≥ 5.0): Orange - Priority maintenance needed
- **MEDIUM** (≥ 3.0): Yellow - Schedule maintenance
- **LOW** (< 3.0): Green - Monitor condition

## 🔍 Technical Details

### Backend (Flask)
- Handles multipart file uploads
- Communicates with Roboflow API
- Calculates weighted severity scores
- Generates visualized output images
- RESTful JSON API

### Frontend
- Vanilla JavaScript (no frameworks)
- Mapbox GL JS for mapping
- Responsive grid layouts
- Real-time preview and results
- Async/await for API calls

### Computer Vision
- Roboflow Serverless API
- Pothole detection model (pothole-detection-gv5e7/3)
- Bounding box predictions
- Confidence scores

## 🛠️ Dependencies

- **Flask** 3.0.0 - Web framework
- **requests** >= 2.31.0 - HTTP client for API calls
- **Pillow** >= 10.1.0 - Image processing and visualization

## 📝 API Endpoints

### POST /detect
Uploads images and returns analysis results.

**Request:**
- `images[]`: Multiple image files
- `road_type`: String
- `road_classification`: String
- `traffic_level`: String
- `location_type`: String
- `latitude`: Number (optional)
- `longitude`: Number (optional)

**Response:**
```json
{
  "success": true,
  "total_images": 2,
  "average_severity_score": 6.45,
  "priority": "HIGH",
  "priority_color": "#FFA500",
  "scoring_weights": {...},
  "results": [...]
}
```

### GET /display-image/<filename>
Returns visualized image with bounding boxes.

## ⚠️ Important Notes

1. **Image Formats**: Supports JPG, JPEG, PNG
2. **File Size Limit**: 16MB per image
3. **API Rate Limits**: Roboflow may have usage limits
4. **GPS Coordinates**: Required for map visualization
5. **Development Server**: Not for production use

## 🎓 Use Cases

- Municipal road maintenance departments
- Infrastructure inspection companies
- Civil engineering assessments
- Road safety audits
- Transportation planning
- Smart city initiatives

## 🌟 Advantages

✅ **Objective Assessment**: Quantitative scoring eliminates subjectivity  
✅ **Prioritization**: Clear priority levels for resource allocation  
✅ **Geospatial Tracking**: Map-based visualization for planning  
✅ **Batch Processing**: Analyze multiple images simultaneously  
✅ **Detailed Reporting**: Comprehensive breakdown of all factors  
✅ **Visual Evidence**: Annotated images for documentation  

## 📊 Sample Output

When you analyze images, you'll see:
- **5-16 potholes detected** per image (typical)
- **Confidence scores**: 40% - 91%
- **Severity scores**: 2.0 - 8.5 depending on conditions
- **Processing time**: ~0.3-0.4 seconds per image

## 🔮 Future Enhancements

Potential improvements:
- Historical data tracking
- Trend analysis over time
- Export reports (PDF, CSV)
- User authentication
- Mobile app integration
- Automated route planning
- Cost estimation for repairs

## 📞 Support

For issues or questions:
1. Check terminal for error messages
2. Verify API keys are valid
3. Ensure internet connection
4. Review Roboflow documentation: https://docs.roboflow.com/
5. Check Mapbox documentation: https://docs.mapbox.com/

---

**Built with ❤️ for the SAMVED HACKATHON**

*Empowering smarter infrastructure management with AI and geospatial intelligence!*
