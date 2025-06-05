import cv2
from ultralytics import YOLO
import requests
import time

# URL del servidor (cambiar según tu usuario de PythonAnywhere)
SERVER_URL = "http://monepii.pythonanywhere.com/update_count"

# Cargar modelo YOLOv8 preentrenado
model = YOLO('yolov8n.pt')

# Abrir la cámara
cap = cv2.VideoCapture(0)

def process_camera():
    if not cap.isOpened():
        print("No se pudo acceder a la cámara")
        return

    while True:
        ret, frame = cap.read()
        if not ret:
            continue

        # Realiza la detección con YOLO
        results = model(frame)

        # Filtra sólo personas (class_id = 0 para "person")
        persons = [det for det in results[0].boxes.data if int(det[5]) == 0]
        current_count = len(persons)

        # Enviar el conteo al servidor
        try:
            response = requests.post(SERVER_URL, json={"count": current_count})
            if response.status_code == 200:
                print(f"Conteo actualizado: {current_count} personas")
            else:
                print("Error al actualizar el conteo")
        except Exception as e:
            print(f"Error de conexión: {e}")

        # Mostrar el frame con el conteo (opcional)
        cv2.putText(frame, f"Personas: {current_count}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        cv2.imshow('Contador de Personas', frame)

        # Salir con 'q'
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        time.sleep(1)  # Actualizar cada segundo

try:
    process_camera()
finally:
    cap.release()
    cv2.destroyAllWindows() 