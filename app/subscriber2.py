import paho.mqtt.client as mqtt
from datetime import datetime
from collections import deque
import json
import time

class BaseCamera:
    def __init__(self, name):
        self.name = name
        self.connection = 'DESCONECTADA'
        self.last_images = []
        self.logs = []
        self.last_seen = None

    def update_from_mqtt(self, data_type, data):
        if data_type == 'CONNECTION':
            if isinstance(data, dict):
                self.connection = 'CONECTADA' if data.get('status', True) else 'DESCONECTADA'
            elif isinstance(data, str):
                data_upper = data.strip().upper()
                if data_upper in ['CONECTADA', 'DESCONECTADA']:
                    self.connection = data_upper
                else:
                    self.connection = data_upper
        elif data_type == 'IMAGE_SAVED':
            # Solo agregar si hay filename o file_path
            # if isinstance(data, dict) and (data.get('filename') or data.get('file_path')):
            #     self.last_images.append(data)
            self.logs.append({
                "level": "INFO",
                "timestamp": datetime.now(),
                "message": f"Captura completa:\n{data.get('filename', data.get('file_path', ''))}\na las {data.get('time', '')}, T={data.get('temperature', '')}°C"
            })
        elif data_type == 'CAPTURE_START':
            self.logs.append({
                "level": "INFO",
                "timestamp": datetime.now(),
                "message": f"Inicio de captura:\nexposición {data.get('exposure_time', '')} us"
            })
        elif data_type == 'FILES':
            self.last_images = []
            for fileinfo in data if isinstance(data, list) else []:
                self.last_images.append(fileinfo)
        elif data_type == 'TEMPERATURE':
            pass  # Implementado en subclases si aplica

    def get_status(self):
        return self.connection

    def get_last_image(self):
        return self.last_images[-1] if self.last_images else None

class AlpyCamera(BaseCamera):
    def __init__(self, name):
        super().__init__(name)
        self.temperature = {'current': None, 'target': -10}

    def update_from_mqtt(self, data_type, data):
        super().update_from_mqtt(data_type, data)
        if data_type == 'TEMPERATURE':
            if isinstance(data, dict) and 'temperature' in data:
                self.temperature['current'] = data['temperature']
            else:
                try:
                    self.temperature['current'] = float(data)
                except Exception:
                    self.temperature['current'] = data

    def get_temperature(self):
        return self.temperature['current']

class QHYCamera(BaseCamera):
    def __init__(self, name):
        super().__init__(name)
        self.temperature = {'current': None, 'target': -10}

    def update_from_mqtt(self, data_type, data):
        super().update_from_mqtt(data_type, data)
        if data_type == 'TEMPERATURE':
            if isinstance(data, dict) and 'temperature' in data:
                self.temperature['current'] = data['temperature']
            else:
                try:
                    self.temperature['current'] = float(data)
                except Exception:
                    self.temperature['current'] = data

    def get_temperature(self):
        return self.temperature['current']

class NikonCamera(BaseCamera):
    def __init__(self, name):
        super().__init__(name)

class TessCamera(BaseCamera):
    def __init__(self, name):
        super().__init__(name)

class AstroDataManager:
    def __init__(self):
        self.cameras = {}
        self.logs = deque(maxlen=100)
        self.heartbeats = {}

    def get_or_create_camera(self, name, camera_type):
        if name not in self.cameras:
            if camera_type == 'alpy':
                self.cameras[name] = AlpyCamera(name)
            elif camera_type == 'qhy':
                self.cameras[name] = QHYCamera(name)
            elif camera_type == 'nikon':
                self.cameras[name] = NikonCamera(name)
            elif camera_type == 'tess':
                self.cameras[name] = TessCamera(name)
            else:
                self.cameras[name] = BaseCamera(name)
        return self.cameras[name]

    def update_camera(self, name, camera_type, data_type, data):
        cam = self.get_or_create_camera(name, camera_type)
        cam.update_from_mqtt(data_type, data)
        cam.last_seen = time.time()

    def get_current_state(self):
        return {name: cam for name, cam in self.cameras.items()}

    def start_mqtt(self, broker="localhost", port=1883, username=None, password=None):
        self.client = mqtt.Client()
        # establecer credenciales si se proporcionan
        if username is not None:
            self.client.username_pw_set(username, password)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.connect(broker, port, 60)
        self.client.subscribe("+/+/+")
        self.client.loop_start()

    def on_connect(self, client, userdata, flags, rc):
        print(f"Conectado al broker MQTT: {rc}")

    def on_message(self, client, userdata, msg):
        topic = msg.topic
        payload = msg.payload.decode('utf-8')
        parts = topic.split("/")
        if len(parts) < 3:
            return
        estacion, camara, tipo = parts[:3]
        camera_type = camara.lower()

        # Parsear payload
        try:
            data = json.loads(payload)
        except Exception:
            data = payload.strip()

        # Mapeo explícito de tipo de evento
        if tipo in ["temperature", "temperature_update"]:
            data_type = "TEMPERATURE"
        elif tipo in ["status", "connection"]:
            data_type = "CONNECTION"
        elif tipo in ["capture_start"]:
            data_type = "CAPTURE_START"
        elif tipo in ["capture_complete"]:
            data_type = "IMAGE_SAVED"
        elif tipo in ["files"]:
            data_type = "FILES"
        elif tipo == "heartbeat":
            self.heartbeats[estacion] = time.time()
            return
        else:
            data_type = tipo.upper()

        # Actualizar cámara
        self.update_camera(f"{estacion}_{camara}", camera_type, data_type, data)

        # Log global
        self.logs.append({
            'timestamp': datetime.now(),
            'level': 'INFO',
            'message': f"{topic}: {data_type} = {str(data)[:50]}"
        })