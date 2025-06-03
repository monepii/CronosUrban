import cv2
from ultralytics import YOLO
from flask import Flask, jsonify
import threading

# Inicializar Flask
app = Flask(__name__)

# Variable global para el contador de personas
person_count = 0

# Cargar modelo YOLOv8 preentrenado
model = YOLO('yolov8n.pt')  # Puedes usar 'yolov8s.pt' para mayor precisión

# Abrir la cámara (ajusta el índice si es necesario)
cap = cv2.VideoCapture(0)

def process_camera():
    global person_count
    if not cap.isOpened():
        print("No se pudo acceder a la cámara")
        return

    while True:
        ret, frame = cap.read()
        if not ret:
            continue  # o break si prefieres detener el proceso

        # Realiza la detección con YOLO
        results = model(frame)

        # Filtra sólo personas (class_id = 0 para "person")
        persons = [det for det in results[0].boxes.data if int(det[5]) == 0]
        person_count = len(persons)
        
        # Opcional: controla la velocidad de procesamiento
        # time.sleep(0.1)

@app.route("/person_count", methods=["GET"])
def get_person_count():
    # Devuelve el contador en formato JSON
    return jsonify({"person_count": person_count})

if __name__ == "__main__":
    # Inicia el procesamiento de la cámara en un hilo separado
    camera_thread = threading.Thread(target=process_camera, daemon=True)
    camera_thread.start()
    # Ejecuta el servidor Flask exponiéndolo en la red local
    app.run(host="0.0.0.0", port=5000)
