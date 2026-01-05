# generate_embedding.py
import sys
import numpy as np
from PIL import Image
import face_recognition
import json

# Check if image path is provided
if len(sys.argv) < 2:
    print(json.dumps({"error": "No image path provided"}))
    sys.exit(1)

image_path = sys.argv[1]

try:
    # Load image and convert to RGB
    img = Image.open(image_path).convert("RGB")
    image = np.ascontiguousarray(np.array(img, dtype=np.uint8))

    # Detect faces
    face_locations = face_recognition.face_locations(image)
    if not face_locations:
        print(json.dumps({"error": "No face detected"}))
        sys.exit(0)

    # Use the first face only
    encoding = face_recognition.face_encodings(image, face_locations)[0]

    # Return embedding as JSON
    print(json.dumps({"embedding": encoding.tolist()}))

except Exception as e:
    print(json.dumps({"error": str(e)}))
