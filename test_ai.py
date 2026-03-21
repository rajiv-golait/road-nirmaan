import requests
import base64
import os
import io
from PIL import Image

# Create a dummy image
img = Image.new('RGB', (100, 100), color = 'red')
img_byte_arr = io.BytesIO()
img.save(img_byte_arr, format='JPEG')
img_byte_arr = img_byte_arr.getvalue()

MODEL_ID = "pothole-detection-gv5e7/3"
API_KEY = "agSdnMe5WdEBWCoBxS8V"

def test_multipart(url):
    print(f"Testing multipart {url}...")
    try:
        res = requests.post(
            f"{url}/{MODEL_ID}",
            params={"api_key": API_KEY},
            files={'file': ("test.jpg", img_byte_arr, 'image/jpeg')}
        )
        print("Status:", res.status_code, "Response:", res.text)
    except Exception as e:
        print("Error:", str(e))

def test_direct(url):
    print(f"Testing direct data {url}...")
    try:
        res = requests.post(
            f"{url}/{MODEL_ID}",
            params={"api_key": API_KEY},
            data=img_byte_arr,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        print("Status:", res.status_code, "Response:", res.text)
    except Exception as e:
        print("Error:", str(e))

test_multipart("https://detect.roboflow.com")
test_direct("https://detect.roboflow.com")
test_multipart("https://serverless.roboflow.com")
test_direct("https://serverless.roboflow.com")
