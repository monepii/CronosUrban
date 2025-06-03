from flask import Flask, jsonify, request
from flask_cors import CORS
import cv2
import numpy as np
from ultralytics import YOLO
import os

app = Flask(__name__)
CORS(app)

# Cargar el modelo YOLO
model = YOLO('yolov8n.pt')

@app.route('/count', methods=['POST'])
def count_people():
    try:
        # Recibir imagen desde la solicitud
        file = request.files['image']
        npimg = np.fromfile(file, np.uint8)
        img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)
        
        # Realizar la detección
        results = model(img)
        
        # Contar personas (clase 0 en COCO dataset)
        person_count = sum(1 for box in results[0].boxes if box.cls == 0)
        
        return jsonify({
            'success': True,
            'count': person_count
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'message': 'Service is running'
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port) 