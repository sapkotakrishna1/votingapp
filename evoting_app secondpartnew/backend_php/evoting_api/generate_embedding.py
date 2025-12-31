import sys
import json
import face_recognition # type: ignore

image_path = sys.argv[1]
image = face_recognition.load_image_file(image_path)
encodings = face_recognition.face_encodings(image)

if len(encodings) > 0:
    embedding = encodings[0].tolist()
    print(json.dumps(embedding))
else:
    print(json.dumps([]))  # No face detected
