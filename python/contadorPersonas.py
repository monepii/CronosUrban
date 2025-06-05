import cv2
from ultralytics import YOLO
from flask import Flask, jsonify, render_template_string, request
import threading
import time

# Inicializar Flask
app = Flask(__name__)

# Variable global para el contador de personas
person_count = 0

# HTML template simple
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Contador de Personas</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            display: flex; 
            justify-content: center; 
            align-items: center; 
            height: 100vh; 
            margin: 0;
            background-color: #f0f2f5;
        }
        .container {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .count {
            font-size: 48px;
            color: #1a73e8;
            margin: 20px 0;
        }
    </style>
    <script>
        function updateCount() {
            fetch('/person_count')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('count').textContent = data.person_count;
                });
        }
        setInterval(updateCount, 1000);
    </script>
</head>
<body>
    <div class="container">
        <h1>Contador de Personas</h1>
        <div class="count" id="count">0</div>
        <p>Personas detectadas</p>
    </div>
</body>
</html>
"""

def simulate_counting():
    global person_count
    while True:
        # Simular detección (en producción esto vendría de tu cámara real)
        person_count = person_count + 1 if person_count < 10 else 0
        time.sleep(2)  # Actualizar cada 2 segundos

@app.route("/")
def home():
    return render_template_string(HTML_TEMPLATE)

@app.route("/update_count", methods=["POST"])
def update_count():
    global person_count
    data = request.get_json()
    if data and 'count' in data:
        person_count = data['count']
        return jsonify({"status": "success"})
    return jsonify({"status": "error"}), 400

@app.route("/person_count", methods=["GET"])
def get_person_count():
    return jsonify({"person_count": person_count})

if __name__ == "__main__":
    # Inicia la simulación en un hilo separado
    counting_thread = threading.Thread(target=simulate_counting, daemon=True)
    counting_thread.start()
    # Ejecuta el servidor Flask
    app.run(host="0.0.0.0", port=5000, debug=True)
