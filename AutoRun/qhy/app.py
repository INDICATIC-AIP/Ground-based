#!/usr/bin/env python3
"""
QHY 16200A — Sistema de control web.
Corre en indicatic-e1. Acceso: http://indicatic-e1:5905
"""

import asyncio
import base64
import hashlib
import io
import json
import logging
import re
import subprocess
import time as _time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
import tornado.ioloop
import tornado.web
import tornado.websocket
from astropy.io import fits
from PIL import Image
from pyindi.webclient import INDIWebApp, INDIHandler

# ── Configuración ─────────────────────────────────────────────────────────────
WEBPORT      = 5905
INDIHOST     = "localhost"
INDIPORT     = 7624
DEVICE       = "QHY CCD 16200A-M"
FITS_DIR     = Path("/home/indicatic-e1/Desktop/ASTRODEVICES/QHYCCDFILE")
UI_QHY_DIR   = Path("/home/indicatic-e1/Desktop/ASTRODEVICES/UI/QHY")
CAMERA_ON_OFF = Path("/home/indicatic-e1/Desktop/app/camera_on_off.sh")
HERE         = Path(__file__).parent
PARAMS_FILE  = HERE / "params.json"
AUTH_FILE    = HERE / "auth.txt"

FILTER_SLOTS = {"U": 1, "B": 2, "V": 3, "R": 4, "I": 5}

# ── Auth ──────────────────────────────────────────────────────────────────────
def _get_password() -> str:
    try:
        return AUTH_FILE.read_text().strip()
    except Exception:
        return "indicatic"

def _cookie_secret() -> str:
    return hashlib.sha256((_get_password() + "qhy_salt").encode()).hexdigest()

def _check_password(pwd: str) -> bool:
    return pwd == _get_password()

class BaseHandler(tornado.web.RequestHandler):
    @property
    def _secret(self):
        return self.application.settings["cookie_secret"]

    def get_current_user(self):
        return self.get_secure_cookie("session")

LOGIN_HTML = """<!DOCTYPE html><html lang="es"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>INDICATIC — Acceso</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0d1117;color:#e6edf3;font-family:'Segoe UI',system-ui,sans-serif;
  display:flex;align-items:center;justify-content:center;min-height:100vh}
.card{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:40px 36px;width:340px;text-align:center}
h1{font-size:1.1rem;color:#58a6ff;margin-bottom:6px}
p{font-size:.8rem;color:#8b949e;margin-bottom:28px}
input{width:100%;background:#0d1117;border:1px solid #30363d;border-radius:6px;
  color:#e6edf3;padding:10px 14px;font-size:.9rem;margin-bottom:14px}
input:focus{outline:1px solid #58a6ff}
button{width:100%;background:#238636;border:none;border-radius:6px;color:#fff;
  padding:11px;font-size:.9rem;font-weight:600;cursor:pointer}
button:hover{background:#2ea043}
.err{color:#f85149;font-size:.8rem;margin-top:10px;display:none}
</style></head><body>
<div class="card">
  <h1>🔭 INDICATIC</h1>
  <p>QHY 16200A — Control remoto</p>
  <form method="post" action="/login">
    <input type="password" name="password" placeholder="Contraseña del laboratorio" autofocus>
    <button type="submit">Entrar</button>
    {error}
  </form>
</div></body></html>"""

class LoginHandler(tornado.web.RequestHandler):
    def get(self):
        self.set_header("Content-Type", "text/html")
        self.write(LOGIN_HTML.replace("{error}", ""))

    def post(self):
        pwd = self.get_argument("password", "")
        if _check_password(pwd):
            self.set_secure_cookie("session", "ok", expires_days=7)
            self.redirect("/")
        else:
            self.set_header("Content-Type", "text/html")
            self.write(LOGIN_HTML.replace(
                "{error}", '<div class="err" style="display:block">Contraseña incorrecta</div>'
            ))

# ── Parámetros ────────────────────────────────────────────────────────────────
_DEFAULT_PARAMS = {
    "exposure":    2.0,
    "target_temp": -5.0,
    "gain":        10,
    "offset":      140,
    "filters":     list(FILTER_SLOTS.keys()),
    "start_time":  "17:10",
    "end_time":    "06:30",
    "auto_start":  True,
}

def _load_params() -> dict:
    try:
        return {**_DEFAULT_PARAMS, **json.loads(PARAMS_FILE.read_text())}
    except Exception:
        return dict(_DEFAULT_PARAMS)

def _save_params():
    try:
        PARAMS_FILE.write_text(json.dumps(params, indent=2))
    except Exception as e:
        logging.warning(f"No se pudo guardar params: {e}")

params = _load_params()

# ── Estado global ─────────────────────────────────────────────────────────────
state = {
    "running":      False,
    "status":       "idle",
    "temperature":  None,
    "camera_hw_ok": False,
    "filter":       None,
    "cycle":        0,
    "counts":       {f: 0 for f in FILTER_SLOTS},
    "indi_ok":      False,
    "power_state":  {"qhy": None},
}

previews            = {f: None for f in FILTER_SLOTS}
ws_clients          = set()
stop_event          = asyncio.Event()
image_event         = asyncio.Event()
camera_ready        = asyncio.Event()
_current_filter     = "U"
_next_save_dir      = None   # None → FITS_DIR (secuencia)
_log_entries: list[str] = []
_last_logged_temp: float | None = None
_last_temp_log_ts: float        = 0.0
_camera_usb_present: bool       = True

# ── Kasa power status ─────────────────────────────────────────────────────────
_KASA_BIN   = Path("/home/indicatic-e1/.local/bin/kasa")
_IDX_TO_DEV = {0: "alpy", 1: "qhy", 2: "nikon"}

def _load_env() -> dict:
    env_path = Path("/home/indicatic-e1/Desktop/.env")
    result = {}
    try:
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                result[k.strip()] = v.strip().strip('"').strip("'")
    except Exception:
        pass
    return result

async def _query_power_status() -> dict:
    env = _load_env()
    ip  = env.get("STRIP_IP", "")
    if not ip:
        return {}
    try:
        proc = await asyncio.create_subprocess_exec(
            str(_KASA_BIN), "--type", "strip", "--host", ip,
            "--username", env.get("STRIP_USER", ""),
            "--password", env.get("STRIP_PASSWORD", ""), "state",
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=12)
        output = stdout.decode(errors="ignore")
    except Exception:
        return {}
    result, cur_idx = {}, None
    for line in output.splitlines():
        s = line.strip()
        m = re.search(r'(?:Child|Plug)\s+(\d+)', s)
        if m:
            cur_idx = int(m.group(1))
        if cur_idx is not None:
            if re.search(r'[Ss]tate\s*[:\-]\s*ON\b', s):
                dev = _IDX_TO_DEV.get(cur_idx)
                if dev:
                    result[dev] = True
            elif re.search(r'[Ss]tate\s*[:\-]\s*OFF\b', s):
                dev = _IDX_TO_DEV.get(cur_idx)
                if dev:
                    result[dev] = False
    return result

async def _power_status_poller():
    await asyncio.sleep(10)
    while True:
        try:
            result = await _query_power_status()
            changed = False
            for dev, val in result.items():
                if dev in state["power_state"] and state["power_state"][dev] != val:
                    state["power_state"][dev] = val
                    changed = True
                elif dev in state["power_state"] and state["power_state"][dev] is None:
                    state["power_state"][dev] = val
                    changed = True
            if changed:
                push_state()
        except Exception:
            pass
        await asyncio.sleep(120)

# ── Logging ───────────────────────────────────────────────────────────────────
def log(msg: str):
    ts    = datetime.now().strftime("%H:%M:%S")
    entry = f"[{ts}] {msg}"
    _log_entries.append(entry)
    if len(_log_entries) > 500:
        _log_entries.pop(0)
    _broadcast({"type": "log", "msg": entry})
    logging.info(msg)

# ── WebSocket broadcast ───────────────────────────────────────────────────────
def _broadcast(data: dict):
    msg = json.dumps(data)
    dead = set()
    for c in ws_clients:
        try:
            c.write_message(msg)
        except Exception:
            dead.add(c)
    ws_clients.difference_update(dead)

def push_state():
    _broadcast({"type": "state", "state": state, "params": params, "previews": previews})

# ── FITS → JPEG ───────────────────────────────────────────────────────────────
def fits_to_jpeg_b64(data: bytes, size=(420, 336)) -> str:
    with fits.open(io.BytesIO(data)) as h:
        arr = h[0].data.astype(np.float32)
    lo, hi = np.percentile(arr, [0.5, 99.5])
    arr = np.clip((arr - lo) / max(hi - lo, 1.0) * 255, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr).resize(size, Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=82)
    return base64.b64encode(buf.getvalue()).decode()

# ── BLOB handler ──────────────────────────────────────────────────────────────
def handle_blob(blob: dict):
    global _current_filter, _next_save_dir
    filt      = _current_filter
    save_dir  = _next_save_dir if _next_save_dir is not None else FITS_DIR
    _next_save_dir = None
    ts        = datetime.now().strftime("%Y%m%dT%H%M%S")
    base      = save_dir / f"{ts}{filt}"
    raw_path  = base.with_suffix(".raw")
    fits_path = base.with_suffix(".fits")

    try:
        with fits.open(io.BytesIO(blob["data"])) as h:
            pixels   = h[0].data
            indi_hdr = h[0].header
        arr_u16 = pixels.astype(np.uint16)
        arr_u16.tofile(raw_path)
        log(f"RAW guardado: {raw_path.name} ({raw_path.stat().st_size // 1024} KB)")
        hdu = fits.PrimaryHDU(arr_u16)
        hdr = hdu.header
        hdr["DATE-OBS"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
        hdr["INSTRUME"] = DEVICE
        hdr["FILTER"]   = filt
        hdr["EXPTIME"]  = params["exposure"]
        hdr["CCD-TEMP"] = state.get("temperature") or 0.0
        hdr["GAIN"]     = params["gain"]
        hdr["OFFSET"]   = params["offset"]
        hdr["XBINNING"] = indi_hdr.get("XBINNING", 1)
        hdr["YBINNING"] = indi_hdr.get("YBINNING", 1)
        hdu.writeto(fits_path, overwrite=True)
        log(f"FITS generado: {fits_path.name}")
    except Exception as e:
        log(f"Error guardando imagen: {e}")
        return

    try:
        previews[filt] = fits_to_jpeg_b64(fits_path.read_bytes())
        state["counts"][filt] += 1
    except Exception as e:
        log(f"Error generando preview: {e}")

    push_state()
    tornado.ioloop.IOLoop.current().add_callback(image_event.set)

# ── Canal INDI ────────────────────────────────────────────────────────────────
_indi_writer = None

async def indi_connect():
    global _indi_writer
    while True:
        try:
            reader, writer = await asyncio.open_connection(INDIHOST, INDIPORT)
            _indi_writer = writer
            writer.write(b'<getProperties version="1.7"/>\n')
            await writer.drain()
            state["indi_ok"] = True
            push_state()
            log("Canal de comandos INDI conectado ✓")
            await asyncio.sleep(2)
            log("Conectando cámara QHY...")
            connect_camera()
            asyncio.ensure_future(_enable_blobs())
            asyncio.ensure_future(_camera_hw_watchdog())
            await _indi_read_loop(reader)
        except Exception as e:
            log(f"INDI no disponible ({e})")
        state["indi_ok"] = False
        state["camera_hw_ok"] = False
        state["temperature"] = None
        camera_ready.clear()
        _indi_writer = None
        push_state()
        log("Reintentando conexión INDI en 30s...")
        await asyncio.sleep(30)

async def _indi_read_loop(reader):
    global _last_logged_temp, _last_temp_log_ts
    buf = ""
    while True:
        try:
            chunk = await reader.read(8192)
            if not chunk:
                break
            buf += chunk.decode(errors="ignore")

            while "CCD_TEMPERATURE_VALUE" in buf:
                i       = buf.find("CCD_TEMPERATURE_VALUE")
                end_tag = buf.find("</oneNumber>", i)
                if end_tag == -1:
                    break
                segment = buf[i:end_tag]
                buf     = buf[end_tag + 12:]
                try:
                    if not _camera_usb_present:
                        continue
                    t      = round(float(segment.split(">")[-1].strip()), 1)
                    now_ts = _time.monotonic()
                    state["temperature"] = t
                    if not state["camera_hw_ok"]:
                        state["camera_hw_ok"] = True
                        log(f"Cámara QHY detectada ✓ (T={t}°C)")
                    if not camera_ready.is_set():
                        camera_ready.set()
                        log(f"Cámara QHY lista ✓ (T={t}°C)")
                    if (_last_logged_temp is None
                            or abs(t - _last_logged_temp) >= 0.5
                            or now_ts - _last_temp_log_ts >= 600):
                        log(f"Temperatura: {t}°C")
                        _last_logged_temp = t
                        _last_temp_log_ts = now_ts
                    push_state()
                except Exception:
                    pass

            if ('name="DISCONNECT">On' in buf
                    or ('name="CONNECT">Off' in buf and camera_ready.is_set())):
                camera_ready.clear()
                state["temperature"] = None
                push_state()
                log("⚠ QHY desconectada (cable/power off)")
                buf = buf.replace('name="DISCONNECT">On', '').replace('name="CONNECT">Off', '')

            if len(buf) > 1_000_000:
                buf = buf[-50_000:]
        except Exception as e:
            log(f"Error leyendo INDI: {e}")
            break

# ── Planificador ──────────────────────────────────────────────────────────────
_last_auto_start_date: str | None = None

def _in_capture_window() -> bool:
    now = datetime.now()
    sm_h, sm_m = map(int, params["start_time"].split(":"))
    en_h, en_m = map(int, params["end_time"].split(":"))
    now_min   = now.hour * 60 + now.minute
    start_min = sm_h * 60 + sm_m
    end_min   = en_h * 60 + en_m
    if start_min > end_min:
        return now_min >= start_min or now_min < end_min
    return start_min <= now_min < end_min

async def daily_scheduler():
    global _last_auto_start_date
    await asyncio.sleep(15)
    if params.get("auto_start", True) and _in_capture_window():
        log("Arranque dentro de ventana nocturna — reanudando captura...")
        for _ in range(18):
            if state["indi_ok"]:
                break
            await asyncio.sleep(10)
        if state["indi_ok"] and not state["running"]:
            asyncio.ensure_future(capture_loop())
    while True:
        await asyncio.sleep(30)
        if not params.get("auto_start", True) or state["running"] or not state["indi_ok"]:
            continue
        now     = datetime.now()
        sh, sm  = map(int, params["start_time"].split(":"))
        start_t = now.replace(hour=sh, minute=sm, second=0, microsecond=0)
        diff    = (now - start_t).total_seconds()
        if 0 <= diff < 300:
            today_key = now.date().isoformat()
            if _last_auto_start_date != today_key:
                _last_auto_start_date = today_key
                log(f"Auto-inicio ({params['start_time']})...")
                asyncio.ensure_future(capture_loop())

# ── INDI helpers ──────────────────────────────────────────────────────────────
def _indi_send(xml: str):
    if _indi_writer and not _indi_writer.is_closing():
        _indi_writer.write((xml + "\n").encode())

def set_number(prop: str, element: str, value: float):
    _indi_send(
        f'<newNumberVector device="{DEVICE}" name="{prop}">'
        f'<oneNumber name="{element}">{value}</oneNumber>'
        f'</newNumberVector>'
    )

def set_switch(prop: str, elements_on: list):
    parts = "".join(f'<oneSwitch name="{e}">On</oneSwitch>' for e in elements_on)
    _indi_send(f'<newSwitchVector device="{DEVICE}" name="{prop}">{parts}</newSwitchVector>')

def connect_camera():
    _indi_send(
        f'<newSwitchVector device="{DEVICE}" name="CONNECTION">'
        f'<oneSwitch name="CONNECT">On</oneSwitch>'
        f'<oneSwitch name="DISCONNECT">Off</oneSwitch>'
        f'</newSwitchVector>'
    )

def get_end_datetime() -> datetime:
    h, m = map(int, params["end_time"].split(":"))
    now  = datetime.now()
    end  = now.replace(hour=h, minute=m, second=0, microsecond=0)
    if end <= now:
        end += timedelta(days=1)
    return end

def get_start_datetime() -> datetime:
    h, m = map(int, params["start_time"].split(":"))
    now   = datetime.now()
    start = now.replace(hour=h, minute=m, second=0, microsecond=0)
    if start < now - timedelta(hours=1):
        start += timedelta(days=1)
    return start

# ── Watchdogs ─────────────────────────────────────────────────────────────────
async def _camera_hw_watchdog():
    global _camera_usb_present
    while state["indi_ok"]:
        await asyncio.sleep(15)
        try:
            proc = await asyncio.create_subprocess_exec(
                "lsusb", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
            present   = b"1618:" in stdout
        except Exception:
            present = True
        _camera_usb_present = present
        if not present and state["camera_hw_ok"]:
            state["camera_hw_ok"] = False
            state["temperature"]  = None
            push_state()
            log("⚠ QHY no detectada en USB — cámara apagada")
        elif present and not state["camera_hw_ok"] and camera_ready.is_set():
            state["camera_hw_ok"] = True
            push_state()
            log("✓ QHY detectada en USB y conectada a INDI")

async def _temp_watchdog():
    tgt = params["target_temp"]
    while state.get("running") and state.get("status") == "capturing":
        await asyncio.sleep(600)
        t = state.get("temperature")
        if t is not None and abs(t - tgt) > 1.0:
            log(f"⚠ T={t}°C lejos de {tgt}°C — reajustando TEC...")
            set_number("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", tgt)

# ── Loop de captura ───────────────────────────────────────────────────────────
async def capture_loop():
    global _current_filter
    stop_event.clear()
    state.update(running=True, status="cooling", cycle=0,
                 counts={f: 0 for f in FILTER_SLOTS}, filter=None)
    push_state()
    log("=== Iniciando secuencia de captura ===")

    POWER_ON_MINS = 5
    start_dt  = get_start_datetime()
    wait_secs = 0 if _in_capture_window() else (start_dt - datetime.now()).total_seconds()
    if wait_secs > 60:
        log(f"Esperando hora de inicio {params['start_time']} ({int(wait_secs//60)} min)...")
        _powered_on = False
        while not stop_event.is_set():
            remaining = (start_dt - datetime.now()).total_seconds()
            if remaining <= 0:
                break
            if not _powered_on and remaining <= POWER_ON_MINS * 60:
                log(f"Encendiendo cámara QHY ({POWER_ON_MINS} min antes)...")
                await _run_power("on", ["qhy"])
                _powered_on = True
            await asyncio.sleep(min(30, remaining))
        if stop_event.is_set():
            await _shutdown()
            return
    else:
        # Ya en ventana activa (inicio inmediato o recuperación tras reinicio)
        log("En ventana activa — encendiendo cámara QHY...")
        await _run_power("on", ["qhy"])
        await asyncio.sleep(15)

    if not camera_ready.is_set():
        log("Esperando cámara QHY...")
        try:
            await asyncio.wait_for(camera_ready.wait(), timeout=180)
        except asyncio.TimeoutError:
            log("Timeout conectando cámara QHY — apagando.")
            await _run_power("off", ["qhy"])
            state.update(running=False, status="idle")
            return

    set_number("CCD_GAIN",   "GAIN",   params["gain"])
    set_number("CCD_OFFSET", "OFFSET", params["offset"])

    tgt = params["target_temp"]
    log(f"Enfriando a {tgt}°C...")
    set_number("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", tgt)
    for _ in range(120):
        if stop_event.is_set():
            break
        t = state["temperature"]
        if t is not None:
            log(f"Temperatura: {t:.1f}°C → {tgt}°C")
            if abs(t - tgt) <= 0.5:
                log(f"Temperatura estabilizada en {t:.1f}°C ✓")
                break
        await asyncio.sleep(5)

    if stop_event.is_set():
        await _shutdown()
        return

    state["status"] = "capturing"
    push_state()
    end_dt = get_end_datetime()
    asyncio.ensure_future(_temp_watchdog())
    log(f"Capturando hasta {params['end_time']} ({end_dt.strftime('%Y-%m-%d %H:%M')})")

    while not stop_event.is_set() and datetime.now() < end_dt:
        state["cycle"] += 1
        log(f"--- Ciclo {state['cycle']} ---")
        for filt in params["filters"]:
            if stop_event.is_set() or datetime.now() >= end_dt:
                break
            _current_filter = filt
            state["filter"] = filt
            push_state()
            slot = FILTER_SLOTS[filt]
            log(f"→ Filtro {filt} (slot {slot}), moviendo rueda...")
            set_number("FILTER_SLOT", "FILTER_SLOT_VALUE", slot)
            await asyncio.sleep(45)
            if stop_event.is_set():
                break
            exp = params["exposure"]
            log(f"  Exponiendo {exp}s...")
            image_event.clear()
            set_number("CCD_EXPOSURE", "CCD_EXPOSURE_VALUE", exp)
            try:
                await asyncio.wait_for(asyncio.shield(image_event.wait()), timeout=exp + 45)
                log(f"  Imagen {filt} recibida ✓")
            except asyncio.TimeoutError:
                log(f"  ⚠ Timeout en filtro {filt}")
        await asyncio.sleep(1)

    await _shutdown()

async def _shutdown():
    state.update(running=False, status="stopping", filter=None)
    stop_event.set()
    push_state()
    log("Terminando secuencia — calentando cámara...")
    set_number("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", 20.0)
    await asyncio.sleep(3)
    log("Apagando cámara QHY...")
    await _run_power("off", ["qhy"])
    state["status"] = "idle"
    push_state()
    log("=== Secuencia finalizada ===")

# ── BLOB channel ──────────────────────────────────────────────────────────────
_web_app = None

async def _enable_blobs():
    await asyncio.sleep(4)
    try:
        await _web_app.client.xml_to_indiserver('<getProperties version="1.7"/>')
        await _web_app.client.xml_to_indiserver(
            f'<enableBLOB device="{DEVICE}">Also</enableBLOB>')
        log("BLOBs habilitados en canal pyindi ✓")
    except Exception as e:
        log(f"Error habilitando BLOBs: {e}")

# ── Handlers HTTP ─────────────────────────────────────────────────────────────
class MainHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self):
        self.indi_render(HERE / "index.html", title="QHY 16200A Control")

    # INDIHandler.indi_render needs to be available
    def indi_render(self, path, **kwargs):
        self.set_header("Content-Type", "text/html")
        self.write(Path(path).read_text())


class FilesHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self):
        self.set_header("Content-Type", "application/json")
        try:
            files = sorted(UI_QHY_DIR.iterdir(), key=lambda f: f.stat().st_mtime, reverse=True)
            result = [
                {"name": f.name, "size": f.stat().st_size, "mtime": f.stat().st_mtime}
                for f in files if f.is_file()
            ][:100]
        except Exception:
            result = []
        self.write(json.dumps(result))


class DeleteHandler(BaseHandler):
    @tornado.web.authenticated
    def delete(self):
        self.set_header("Content-Type", "application/json")
        name = self.get_argument("name", "")
        path = UI_QHY_DIR / Path(name).name
        if path.exists() and path.parent.resolve() == UI_QHY_DIR.resolve():
            path.unlink()
            self.write({"ok": True})
        else:
            self.set_status(400)
            self.write({"ok": False})


class PowerHandler(BaseHandler):
    @tornado.web.authenticated
    async def post(self):
        self.set_header("Content-Type", "application/json")
        body    = json.loads(self.request.body)
        action  = body.get("action", "off")
        devices = body.get("devices", [])
        if action not in ("on", "off") or not devices:
            self.set_status(400)
            self.write({"ok": False})
            return
        try:
            proc = await asyncio.create_subprocess_exec(
                str(CAMERA_ON_OFF), action, *devices,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=15)
            out = stdout.decode(errors="ignore").strip()
            log(f"[Power] {action} {' '.join(devices)}: {out or 'ok'}")
            for dev in devices:
                if dev in state["power_state"]:
                    state["power_state"][dev] = (action == "on")
            push_state()
            self.write({"ok": True, "output": out})
        except Exception as e:
            self.set_status(500)
            self.write({"ok": False, "error": str(e)})


class CtrlWS(tornado.websocket.WebSocketHandler):
    def open(self):
        if not self.get_secure_cookie("session"):
            self.close(code=4001, reason="Unauthorized")
            return
        ws_clients.add(self)
        self.write_message(json.dumps({
            "type":     "init",
            "state":    state,
            "params":   params,
            "previews": previews,
            "log":      _log_entries[-100:],
        }))

    def on_message(self, raw: str):
        try:
            data = json.loads(raw)
        except Exception:
            return
        cmd = data.get("cmd")

        if cmd == "start":
            if not state["running"]:
                p = data.get("params", {})
                if p:
                    params.update(p)
                    _save_params()
                asyncio.ensure_future(capture_loop())

        elif cmd == "stop":
            if state["running"]:
                stop_event.set()
                log("Detención solicitada...")

        elif cmd == "abort":
            stop_event.set()
            set_switch("CCD_ABORT_EXPOSURE", ["ABORT"])
            state.update(running=False, status="idle", filter=None)
            push_state()
            log("Captura abortada")

        elif cmd == "params":
            params.update(data.get("params", {}))
            _save_params()
            log(f"Parámetros actualizados")

        elif cmd == "cool":
            tgt = data.get("temp", params["target_temp"])
            set_number("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", tgt)
            log(f"Temperatura objetivo: {tgt}°C")

        elif cmd == "single":
            global _next_save_dir
            filt = data.get("filter", _current_filter)
            exp  = data.get("exposure", params["exposure"])
            _next_save_dir = UI_QHY_DIR
            log(f"Captura rápida: filtro {filt}, {exp}s → UI/QHY")
            set_number("FILTER_SLOT", "FILTER_SLOT_VALUE", FILTER_SLOTS.get(filt, 1))
            asyncio.ensure_future(_single_shot(filt, exp))

        elif cmd == "power":
            asyncio.ensure_future(_run_power(
                data.get("action", "off"), data.get("devices", [])))

    def on_close(self):
        ws_clients.discard(self)

    def check_origin(self, origin):
        return True


async def _single_shot(filt: str, exp: float):
    global _current_filter
    if not camera_ready.is_set():
        log("Esperando cámara...")
        try:
            await asyncio.wait_for(camera_ready.wait(), timeout=30)
        except asyncio.TimeoutError:
            log("⚠ Timeout esperando cámara")
            return
    _current_filter = filt
    await asyncio.sleep(5)
    log(f"  Exponiendo {exp}s...")
    image_event.clear()
    set_number("CCD_EXPOSURE", "CCD_EXPOSURE_VALUE", exp)
    try:
        await asyncio.wait_for(asyncio.shield(image_event.wait()), timeout=exp + 30)
        log(f"Captura rápida {filt} completada ✓")
    except asyncio.TimeoutError:
        log(f"⚠ Timeout en captura rápida {filt}")


async def _run_power(action: str, devices: list):
    if action not in ("on", "off") or not devices:
        return
    try:
        proc = await asyncio.create_subprocess_exec(
            str(CAMERA_ON_OFF), action, *devices,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=15)
        log(f"[Power] {action} {' '.join(devices)}: {stdout.decode(errors='ignore').strip() or 'ok'}")
        for dev in devices:
            if dev in state["power_state"]:
                state["power_state"][dev] = (action == "on")
        push_state()
    except Exception as e:
        log(f"[Power] Error: {e}")


class RestartHandler(BaseHandler):
    @tornado.web.authenticated
    async def post(self):
        self.set_header("Content-Type", "application/json")
        self.finish(json.dumps({"ok": True}))
        subprocess.Popen(
            ["bash", "-c", "sleep 2 && systemctl --user restart qhy-control"],
            start_new_session=True,
        )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    FITS_DIR.mkdir(parents=True, exist_ok=True)
    UI_QHY_DIR.mkdir(parents=True, exist_ok=True)
    if not AUTH_FILE.exists():
        AUTH_FILE.write_text("indicatic")
        logging.info(f"Auth creado con contraseña por defecto en {AUTH_FILE}")

    loop = tornado.ioloop.IOLoop.current()
    loop.spawn_callback(indi_connect)
    loop.spawn_callback(daily_scheduler)
    loop.spawn_callback(_power_status_poller)

    _web_app = INDIWebApp(
        webport=WEBPORT,
        indihost=INDIHOST,
        indiport=INDIPORT,
        handle_blob=handle_blob,
    )
    logging.info(f"QHY Control arrancando en http://0.0.0.0:{WEBPORT}")
    _web_app.build_app(
        [
            (r"/login",   LoginHandler),
            (r"/",        MainHandler),
            (r"/ws",      CtrlWS),
            (r"/files",   FilesHandler),
            (r"/delete",  DeleteHandler),
            (r"/power",   PowerHandler),
            (r"/restart", RestartHandler),
        ],
        cookie_secret=_cookie_secret(),
        login_url="/login",
    )
