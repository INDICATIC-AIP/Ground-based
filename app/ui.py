import os
import time
import logging
from logging.handlers import RotatingFileHandler
from textual.app import App, ComposeResult
from textual.widgets import Footer, Header, Static, ListView, ListItem, Label, TabbedContent, TabPane, Switch, Button
from textual.containers import Horizontal, Vertical, Grid
from textual.screen import ModalScreen
from subscriber2 import AstroDataManager
from ssh_comand import send_ssh_command
from textual import work
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
load_dotenv()

# Configuración desde variables de entorno
LAPTOP = os.getenv('LAPTOP_BROKER_IP')  # Sin default - debe configurarse
SERVER = os.getenv('SERVER_BROKER_IP')  # Sin default - debe configurarse
MQTT_BROKER = LAPTOP  # Usar broker laptop por defecto
MQTT_PORT = int(os.getenv('MQTT_PORT', '1883'))  # Puerto tiene default seguro
data_manager = AstroDataManager()
MQTT_USER = os.getenv('LAPTOP_USER')      # Sin default - credencial sensible
MQTT_PASS = os.getenv('LAPTOP_PASSWORD')  # Sin default - credencial sensible
data_manager.start_mqtt(broker=MQTT_BROKER, port=MQTT_PORT, username=MQTT_USER, password=MQTT_PASS)

LOG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "astroUI.log")
logger = logging.getLogger("AstroUI")
logger.setLevel(logging.INFO)
if not logger.handlers:
    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
    except Exception:
        pass
    _fh = RotatingFileHandler(LOG_PATH, maxBytes=1_000_000, backupCount=3, encoding="utf-8")
    _fh.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))
    logger.addHandler(_fh)

class CameraStatusWidget(Static):
    def __init__(self, camera_name: str, camera_type: str):
        super().__init__()
        self.camera_name = camera_name
        self.camera_type = camera_type

    def compose(self) -> ComposeResult:
        with Horizontal():
            with Vertical(classes="camera-info"):
                yield Static(f"📷 {self.camera_name.upper()}", id=f"{self.camera_name}-title")
                yield Static("Estado: --", id=f"{self.camera_name}-status")
                yield Static("  --°C (--°C)", classes="temp-display",id=f"{self.camera_name}-temp")
            with Vertical(classes="images-section"):
                yield Static(" IMÁGENES", id=f"{self.camera_name}-images-title")
                yield ListView(id=f"{self.camera_name}-images-list")

    def update_data(self, camera_obj):
        if not camera_obj:
            return
        now = time.time()
        last_seen = getattr(camera_obj, 'last_seen', None)
        timeout = last_seen is not None and now - last_seen > 10
        if timeout:
            connection = 'DESCONECTADA'
            last_images = []
            current = '--'
            target = '--'
        else:
            connection = getattr(camera_obj, 'connection', 'DESCONECTADA')
            last_images = getattr(camera_obj, 'last_images', [])
            temp = getattr(camera_obj, 'temperature', {})
            current = temp.get("current", "--")
            target = temp.get("target", "--")
        # status_circle = "🟢" if connection.lower() == "conectada" or connection.lower() == "connected" else "🔴"
        status = f"Estado: {connection.capitalize()}"
        self.query_one(f"#{self.camera_name}-status").update(status)
        self.query_one(f"#{self.camera_name}-temp").update(f"  {current}°C ({target}°C)")
        images_list = self.query_one(f"#{self.camera_name}-images-list")
        images_list.clear()
        if last_images:
            for img in last_images:
                filename = img.get("filename", img.get("filepath", "Sin nombre"))
                filesize = img.get("filesize", None)
                filesize_human = img.get("filesize_human", None)
                if filesize_human is None and filesize is not None:
                    try:
                        from subscriber2 import BaseCamera
                        filesize_human = BaseCamera.human_readable_size(filesize)
                    except Exception:
                        filesize_human = None
                if filesize_human:
                    label = f"{filename} ({filesize_human})"
                elif filesize is not None:
                    label = f"{filename} ({filesize} bytes)"
                else:
                    label = f"{filename}"
                images_list.append(ListItem(Label(label)))
        else:
            images_list.append(ListItem(Label("Sin imágenes")))

class JetsonStatusWidget(Static):
    def compose(self) -> ComposeResult:
        yield Static("🛰️ JETSON STATUS")
        yield Static("Estado: --", id="jetson-status")
        yield Static("Nombre: --", id="jetson-name")
        yield Static("Imágenes: 0", id="jetson-stats")

    def update_data(self, jetson_name, cameras_objs, heartbeat_ts=None):
        now = time.time()
        cameras = list(cameras_objs.values()) if cameras_objs else []
        if heartbeat_ts is not None and now - heartbeat_ts > 15:
            status = "Estado: sin comunicación"
            name = f"Nombre: {jetson_name}" if jetson_name else "Nombre: --"
            images = "Imágenes: 0"
        elif cameras and all(getattr(cam, 'last_seen', 0) is not None and now - getattr(cam, 'last_seen', 0) > 10 for cam in cameras):
            status = "Estado: offline"
            name = f"Nombre: {jetson_name}" if jetson_name else "Nombre: --"
            images = "Imágenes: 0"
        else:
            status = "Estado: online" if cameras_objs else "Estado: offline"
            name = f"Nombre: {jetson_name}" if jetson_name else "Nombre: --"
            total_images = sum(len(getattr(cam, 'last_images', [])) for cam in cameras_objs.values()) if cameras_objs else 0
            images = f"Imágenes: {total_images}"
        self.query_one("#jetson-status").update(status)
        self.query_one("#jetson-name").update(name)
        self.query_one("#jetson-stats").update(images)

class LogsWidget(ListView):
    def update_logs(self, logs):
        self.clear()
        for log in logs[-10:]:
            
            timestamp = log["timestamp"]
            if hasattr(timestamp, 'strftime'):
                time_str = timestamp.strftime('%H:%M:%S')
            else:
                time_str = str(timestamp)
            text = f"> [{time_str}] {log['message']}"
            self.append(ListItem(Label(text)))

class AstroUI(App):
    CSS_PATH = "astroUI.tcss"
    STATION_CREDENTIALS = {
        "indicatic": {
            "username": os.getenv('INDICATIC_SSH_USER'),  # Sin default - credencial sensible
            "hostname": os.getenv('INDICATIC_SSH_HOST'),  # Sin default - IP sensible  
            "password": os.getenv('INDICATIC_SSH_PASSWORD'),  # Sin default - credencial sensible
        },
        "indicatice2": {
            "username": os.getenv('INDICATICE2_SSH_USER'),  # Sin default - credencial sensible
            "hostname": os.getenv('INDICATICE2_SSH_HOST'),  # Sin default - IP sensible
            "password": os.getenv('INDICATICE2_SSH_PASSWORD'),  # Sin default - credencial sensible
        },
    }
    BINDINGS = [
        ("q", "quit", "Salir"),
        ("s", "next_station", "Siguiente estación"),
        ("f", "next_camera", "Siguiente cámara"),
        ("a", "show_quit_screen", "Apagar Cámara")
    ]
    def __init__(self):
        super().__init__()
        self.stations = []
        self.station_index = 0
        self.current_station = None
        self.update_timer = None
        self.camera_widgets = {}
        self.camera_tabs = []
        self.current_camera_index = 0
        self.logs = []

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical(classes="camera-control"):
                yield Horizontal(
                    Static("UTP", classes="label"),
                    Switch(value=False, id="switch-utp"),
                    classes="container",
                )
                yield Horizontal(
                    Static("COL", classes="label"),
                    Switch(value=False, id="switch-col"),
                    classes="container",
                )
                yield Horizontal(
                    Static("SMT", classes="label"),
                    Switch(value=False, id="switch-smt"),
                    classes="container",
                )
            with Vertical(classes="sidebar"):
                yield JetsonStatusWidget(id="jetson-status")
                yield Static("LOGS RECIENTES")
                yield LogsWidget(id="logs-list")
            with Vertical(classes="main-content"):
                yield Static("", id="station-banner")
                yield TabbedContent(id="cameras-tabs")
        yield Footer()

    async def on_mount(self):
        self.title = "AstroUI"
        # self.sub_title = "Monitoreo en tiempo real"
        self.update_timer = self.set_interval(2.0, self.update_display)
        await self.update_display()

    def get_stations_dict(self):
        cameras = data_manager.get_current_state()
        stations = {}
        for cam_name, cam_obj in cameras.items():
            if '_' in cam_name:
                station, camera = cam_name.split('_', 1)
            else:
                station, camera = 'default', cam_name
            if station not in stations:
                stations[station] = {}
            stations[station][camera] = cam_obj
        return stations

    async def rebuild_camera_tabs(self, cameras_dict):
        tabbed_content = self.query_one("#cameras-tabs")
        await tabbed_content.clear_panes()
        self.camera_widgets.clear()
        self.camera_tabs.clear()
        self.current_camera_index = 0
        for camera_name, camera_obj in cameras_dict.items():
            camera_type = getattr(camera_obj, 'name', camera_name).lower()
            camera_widget = CameraStatusWidget(camera_name, camera_type)
            self.camera_widgets[camera_name] = camera_widget
            tab_id = f"tab-{camera_name}"
            tab_pane = TabPane(camera_name.upper(), camera_widget, id=tab_id)
            await tabbed_content.add_pane(tab_pane)
            self.camera_tabs.append(tab_id)
            camera_widget.update_data(camera_obj)

    async def update_display(self):
        stations_dict = self.get_stations_dict()
        self.stations = list(stations_dict.keys())
        if not self.stations:
            banner = self.query(".main-content Static").first()
            if banner:
                banner.update(" Sin comunicación con ninguna estación (broker o red caídos)")
            return
        if self.station_index >= len(self.stations):
            self.station_index = 0
        station_name = self.stations[self.station_index]
        cameras_dict = stations_dict[station_name]
        self.current_station = station_name
        now = time.time()
        heartbeat_ts = getattr(data_manager, 'heartbeats', {}).get(station_name, None)
        banner = self.query(".main-content Static").first()
        if heartbeat_ts is not None and now - heartbeat_ts > 15:
            banner.update(f" Estación: {station_name} - SIN COMUNICACIÓN (heartbeat perdido)")
        else:
            banner.update(f" Estación: {station_name} - Monitoreo en tiempo real")
        banner.remove_class("station-jetson1", "station-jetson2", "station-jetson3", "station-jetson4", "station-jetson5", "station-jetson6")
        banner.add_class(f"station-{station_name.lower()}")
        jetson_widget = self.query_one(JetsonStatusWidget)
        jetson_widget.update_data(station_name, cameras_dict, heartbeat_ts=heartbeat_ts)
        current_cameras = set(self.camera_widgets.keys())
        new_cameras = set(cameras_dict.keys())
        if current_cameras != new_cameras:
            await self.rebuild_camera_tabs(cameras_dict)
        else:
            for camera_name, camera_obj in cameras_dict.items():
                if camera_name in self.camera_widgets:
                    self.camera_widgets[camera_name].update_data(camera_obj)
        self.update_logs_for_active_camera(cameras_dict)

    def update_logs_for_active_camera(self, cameras_dict):
        try:
            tabbed_content = self.query_one("#cameras-tabs")
            active_tab = tabbed_content.active
            if active_tab:
                camera_name = active_tab.replace("tab-", "")
                camera_obj = cameras_dict.get(camera_name)
                logs_widget = self.query_one(LogsWidget)
                logs = getattr(camera_obj, 'logs', []) if camera_obj and hasattr(camera_obj, 'logs') else []
                # Solo actualiza si los logs cambiaron
                if getattr(logs_widget, "_last_logs", None) != logs:
                    logs_widget.update_logs(logs)
                    logs_widget._last_logs = list(logs)  # Guarda copia para comparar
                logs_title = self.query_one(".sidebar").children[1]
                logs_title.update(f"LOGS {camera_name.upper()}")
        except Exception:
            pass

    async def action_refresh(self):
        await self.update_display()

    async def action_next_station(self):
        if self.stations and len(self.stations) > 1:
            self.station_index = (self.station_index + 1) % len(self.stations)
            await self.update_display()
        else:
            self.notify("No hay estaciones disponibles.")

    async def action_next_camera(self):
        if len(self.camera_tabs) > 1:
            try:
                tabbed_content = self.query_one("#cameras-tabs")
                self.current_camera_index = (self.current_camera_index + 1) % len(self.camera_tabs)
                next_tab_id = self.camera_tabs[self.current_camera_index]
                tabbed_content.active = next_tab_id
                self.update_logs_for_active_camera(self.get_stations_dict()[self.current_station])
            except Exception:
                pass
        else:
            self.notify("No hay cámaras disponibles.")

    def turn_on_station(self, station_name, is_on: bool):
        creds = self.STATION_CREDENTIALS.get(station_name.lower())
        if not creds:
            self.notify(f"Sin credenciales para {station_name}")
            return
        cmd = f"ls /home/{creds['username']}/Desktop/app/"
        output, error, status = send_ssh_command(
            username=creds["username"],
            hostname=creds["hostname"],
            password=creds["password"],
            command=cmd,
        )
        if output is not None:
            print(f"Output:\n{output}")
            if error:
                print(f"Error:\n{error}")
            print(f"Exit status: {status}")
        else:
            print(f"Connection failed: {error}")

    def on_switch_changed(self, event: Switch.Changed) -> None:
        switch_id = event.switch.id
        is_on = event.value
        if switch_id == "switch-utp":
            station = "UTP"
            self.turn_on_station(station, is_on)
        elif switch_id == "switch-col":
            station = "COL"
            self.turn_on_station(station, is_on)
        elif switch_id == "switch-smt":
            station = "SMT"
            self.turn_on_station(station, is_on)
        else:
            return

    async def action_show_quit_screen(self):
        try:
            tabbed_content = self.query_one("#cameras-tabs")
            active_tab = tabbed_content.active
            if not active_tab:
                self.notify("No hay cámara activa.")
                return
            camera_name = active_tab.replace("tab-", "")
            station_key = (self.current_station or "").lower()
            creds = self.STATION_CREDENTIALS.get(station_key)
            if not station_key:
                self.notify("No hay estación activa.")
                return
            if not creds:
                self.notify(f"Sin credenciales para {station_key}.")
                return
            self.push_screen(
                QuitScreen(
                    camera_name=camera_name,
                    station=station_key,
                    username=creds["username"],
                    hostname=creds["hostname"],
                    password=creds["password"],
                )
            )
        except Exception:
            self.notify("Error de pantalla: apagado de cámara.")

    def on_unmount(self):
        if self.update_timer:
            self.update_timer.stop()
        if hasattr(data_manager, 'client') and data_manager.client:
            data_manager.client.loop_stop()
            data_manager.client.disconnect()

class QuitScreen(ModalScreen):
    CSS = """
    QuitScreen {
        align: center middle;
    }
    #dialog {
        grid-size: 2;
        grid-gutter: 1 2;
        grid-rows: 1fr 3;
        padding: 0 1;
        width: 60;
        height: 11;
        border: thick $background 80%;
        background: $surface;
    }
    #question {
        column-span: 2;
        height: 1fr;
        width: 1fr;
        content-align: center middle;
    }
    Button {
        width: 100%;
    }
    """
    def __init__(self, camera_name: str = "", station: str = "", username: str = "", hostname: str = "", password: str = ""):
        super().__init__()
        self.camera_name = camera_name
        self.station = station
        self.username = username
        self.hostname = hostname
        self.password = password

    def compose(self) -> ComposeResult:
        message = f"¿Desea apagar la cámara {self.camera_name.upper()}?" if self.camera_name else "¿Está seguro que desea salir?"
        button_text = "Apagar" if self.camera_name else "Salir"
        yield Grid(
            Label(message, id="question"),
            Button(button_text, variant="error", id="shutdown"),
            Button("Cancelar", variant="primary", id="cancel"),
            id="dialog",
        )

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "shutdown":
            if self.camera_name:
                question = self.query_one("#question", Label)
                shutdown_btn = self.query_one("#shutdown", Button)
                cancel_btn = self.query_one("#cancel", Button)
                shutdown_btn.disabled = True
                cancel_btn.disabled = True
                question.update(f"Apagando {self.camera_name.upper()}...")
                cmd = f"/home/{self.username}/Desktop/app/camera_on_off.sh off {self.camera_name.lower()}"
                logger.info("Inicio apagado cámara=%s estación=%s host=%s user=%s",
                            self.camera_name, self.station, self.hostname, self.username)
                self.perform_shutdown(cmd)
            else:
                self.app.exit()
        else:
            self.app.pop_screen()

    @work(exclusive=True, thread=True)
    async def perform_shutdown(self, cmd: str):
        try:
            output, error, status = send_ssh_command(
                username=self.username,
                hostname=self.hostname,
                password=self.password,
                command=cmd,
            )
            if output is not None:
                self.app.call_from_thread(self.app.notify, f"[{self.station}] {self.camera_name}: status={status}")
                logger.info("Apagado completado cámara=%s estación=%s status=%s", self.camera_name, self.station, status)
                if error:
                    self.app.call_from_thread(self.app.notify, f"Error: {error}")
                    logger.warning("STDERR apagado cámara=%s estación=%s: %s", self.camera_name, self.station, error)
            else:
                self.app.call_from_thread(self.app.notify, f"Conexión fallida: {error}")
                logger.error("Conexión fallida apagando cámara=%s estación=%s: %s", self.camera_name, self.station, error)
        except Exception:
            self.app.call_from_thread(self.app.notify, "Error al apagar la cámara")
            logger.exception("Excepción apagando cámara=%s estación=%s", self.camera_name, self.station)
        finally:
            self.app.call_from_thread(self.app.pop_screen)

if __name__ == "__main__":
    app = AstroUI()
    app.run()