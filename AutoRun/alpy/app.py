#!/usr/bin/env python3
"""
ALPY 600 (SX CCD SX-825) + Nikon D5600 — Sistema de control web.
Corre en indicatice2. Acceso: http://indicatice2:5906
"""

import asyncio
import base64
import hashlib
import io
import json
import logging
import re
import signal
import subprocess
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
WEBPORT       = 5906
INDIHOST      = "localhost"
INDIPORT      = 7624
DEVICE_ALPY   = "SX CCD SX-825"
ALPYFILE_DIR  = Path("/home/indicatice2/Desktop/ASTRODEVICES/ALPYFILE")
NIKONFILE_DIR = Path("/home/indicatice2/Desktop/ASTRODEVICES/NIKONFILE")
UI_ALPY_DIR   = Path("/home/indicatice2/Desktop/ASTRODEVICES/UI/ALPY")
UI_NIKON_DIR  = Path("/home/indicatice2/Desktop/ASTRODEVICES/UI/NIKON")
NIKON_SCRIPT  = Path("/home/indicatice2/Desktop/code/nikon.sh")
CAMERA_ON_OFF = Path("/home/indicatice2/Desktop/app/camera_on_off.sh")
HERE          = Path(__file__).parent
PARAMS_FILE   = HERE / "params.json"
AUTH_FILE     = HERE / "auth.txt"

# ── Auth ──────────────────────────────────────────────────────────────────────
def _get_password() -> str:
    try:
        return AUTH_FILE.read_text().strip()
    except Exception:
        return "indicatic"

def _cookie_secret() -> str:
    return hashlib.sha256((_get_password() + "alpy_salt").encode()).hexdigest()

def _check_password(pwd: str) -> bool:
    return pwd == _get_password()

class BaseHandler(tornado.web.RequestHandler):
    def get_current_user(self):
        return self.get_secure_cookie("session")

_LOGIN_HTML = """<!DOCTYPE html><html lang="es"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>INDICATIC — Acceso</title>
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
body{{background:#0d1117;color:#e6edf3;font-family:'Segoe UI',system-ui,sans-serif;
  display:flex;align-items:center;justify-content:center;min-height:100vh}}
.card{{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:40px 36px;width:340px;text-align:center}}
h1{{font-size:1.1rem;color:#58a6ff;margin-bottom:6px}}
p{{font-size:.8rem;color:#8b949e;margin-bottom:28px}}
input{{width:100%;background:#0d1117;border:1px solid #30363d;border-radius:6px;
  color:#e6edf3;padding:10px 14px;font-size:.9rem;margin-bottom:14px}}
input:focus{{outline:1px solid #58a6ff}}
button{{width:100%;background:#238636;border:none;border-radius:6px;color:#fff;
  padding:11px;font-size:.9rem;font-weight:600;cursor:pointer}}
button:hover{{background:#2ea043}}
.err{{color:#f85149;font-size:.8rem;margin-top:10px}}
</style></head><body>
<div class="card">
  <h1>🔭 INDICATIC</h1>
  <p>ALPY 600 + Nikon D5600 — Control remoto</p>
  <form method="post" action="/login">
    <input type="password" name="password" placeholder="Contraseña del laboratorio" autofocus>
    <button type="submit">Entrar</button>
    {error}
  </form>
</div></body></html>"""

class LoginHandler(tornado.web.RequestHandler):
    def get(self):
        self.set_header("Content-Type", "text/html")
        self.write(_LOGIN_HTML.format(error=""))

    def post(self):
        pwd = self.get_argument("password", "")
        if _check_password(pwd):
            self.set_secure_cookie("session", "ok", expires_days=7)
            self.redirect("/")
        else:
            self.set_header("Content-Type", "text/html")
            self.write(_LOGIN_HTML.format(
                error='<div class="err">Contraseña incorrecta</div>'))

# ── Parámetros persistentes ───────────────────────────────────────────────────
_DEFAULT_PARAMS = {
    "alpy_exposure":  10.0,    # tiempo exposición CCD (s)
    "alpy_delay":     300.0,   # pausa entre capturas (s)
    "target_temp":    -5.0,
    "start_time":     "17:10",
    "end_time":       "06:30",
    "auto_start":     True,
    "nikon_exposure": 10.0,    # exposición rápida Nikon (s)
    "nikon_iso":      800,     # ISO Nikon
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
    "alpy_running":  False,
    "alpy_status":   "idle",
    "temperature":   None,
    "alpy_count":    0,
    "indi_ok":       False,
    "nikon_running": False,
    "nikon_count":   0,
    "power_state":   {"alpy": None, "nikon": None},
}

alpy_preview      = None
nikon_preview     = None       # base64 JPEG del último NEF
_next_save_dir    = None       # None → ALPYFILE_DIR (secuencia)
_start_nikon_too  = False      # "Iniciar Ambas" — Nikon se lanza al encender cámaras
ws_clients        = set()
stop_alpy_event = asyncio.Event()
image_event     = asyncio.Event()
camera_ready    = asyncio.Event()
_log_entries: list[str] = []
_last_auto_start_date: str | None = None

# ── Kasa power status ─────────────────────────────────────────────────────────
_KASA_BIN   = Path("/home/indicatice2/.local/bin/kasa")
_IDX_TO_DEV = {0: "alpy", 1: "qhy", 2: "nikon"}

def _load_env() -> dict:
    env_path = Path("/home/indicatice2/Desktop/.env")
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
                if dev and dev in state["power_state"]:
                    result[dev] = True
            elif re.search(r'[Ss]tate\s*[:\-]\s*OFF\b', s):
                dev = _IDX_TO_DEV.get(cur_idx)
                if dev and dev in state["power_state"]:
                    result[dev] = False
    return result

async def _power_status_poller():
    await asyncio.sleep(10)
    while True:
        try:
            result = await _query_power_status()
            changed = False
            for dev, val in result.items():
                if state["power_state"].get(dev) != val:
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
    _broadcast({
        "type":          "state",
        "state":         state,
        "params":        params,
        "preview":       alpy_preview,
        "nikon_preview": nikon_preview,
    })

# ── Imagen ────────────────────────────────────────────────────────────────────
def fits_to_jpeg_b64(data: bytes, size=(640, 480)) -> str:
    with fits.open(io.BytesIO(data)) as h:
        arr = h[0].data.astype(np.float32)
    lo, hi = np.percentile(arr, [0.5, 99.5])
    arr = np.clip((arr - lo) / max(hi - lo, 1.0) * 255, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr).resize(size, Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=82)
    return base64.b64encode(buf.getvalue()).decode()

def extract_nef_preview(path: Path) -> bytes | None:
    """Extrae el JPEG más grande embebido en un NEF escaneando marcadores SOI/EOI."""
    try:
        data = path.read_bytes()
        best = b""
        pos  = 0
        while True:
            start = data.find(b'\xff\xd8\xff', pos)
            if start == -1:
                break
            end = data.find(b'\xff\xd9', start + 4)
            if end == -1:
                break
            chunk = data[start:end + 2]
            if len(chunk) > len(best):
                best = chunk
            pos = end + 2
        return best or None
    except Exception:
        return None

async def _update_nikon_preview():
    global nikon_preview
    try:
        nefs = sorted(
            list(NIKONFILE_DIR.glob("*.NEF")) + list(UI_NIKON_DIR.glob("*.NEF")),
            key=lambda f: f.stat().st_mtime, reverse=True,
        )
        if not nefs:
            return
        loop = asyncio.get_event_loop()
        jpeg = await loop.run_in_executor(None, extract_nef_preview, nefs[0])
        if jpeg:
            nikon_preview = base64.b64encode(jpeg).decode()
            push_state()
    except Exception as e:
        logging.warning(f"Nikon preview error: {e}")

# ── BLOB handler ──────────────────────────────────────────────────────────────
def handle_blob(blob: dict):
    global alpy_preview, _next_save_dir
    save_dir       = _next_save_dir if _next_save_dir is not None else ALPYFILE_DIR
    _next_save_dir = None
    ts             = datetime.now().strftime("%Y%m%dT%H%M%S")
    fits_path      = save_dir / f"{ts}.fits"
    try:
        with fits.open(io.BytesIO(blob["data"])) as h:
            pixels   = h[0].data
            indi_hdr = h[0].header
        arr_u16 = pixels.astype(np.uint16)
        hdu = fits.PrimaryHDU(arr_u16)
        hdr = hdu.header
        hdr["DATE-OBS"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
        hdr["INSTRUME"] = DEVICE_ALPY
        hdr["EXPTIME"]  = params["alpy_exposure"]
        hdr["CCD-TEMP"] = state.get("temperature") or 0.0
        hdr["XBINNING"] = indi_hdr.get("XBINNING", 1)
        hdr["YBINNING"] = indi_hdr.get("YBINNING", 1)
        hdu.writeto(fits_path, overwrite=True)
        log(f"FITS guardado: {fits_path.name} ({fits_path.stat().st_size // 1024} KB)")
    except Exception as e:
        log(f"Error guardando imagen ALPY: {e}")
        return
    try:
        alpy_preview = fits_to_jpeg_b64(fits_path.read_bytes())
        state["alpy_count"] += 1
    except Exception as e:
        log(f"Error generando preview: {e}")
    push_state()
    tornado.ioloop.IOLoop.current().add_callback(image_event.set)

# ── Canal INDI ────────────────────────────────────────────────────────────────
_indi_writer: asyncio.StreamWriter | None = None

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
            log("Canal INDI conectado ✓")
            await asyncio.sleep(2)
            log("Conectando SX-825...")
            _connect_camera()
            asyncio.ensure_future(_enable_blobs())
            asyncio.ensure_future(_camera_connect_watchdog())
            await _indi_read_loop(reader)
        except Exception as e:
            log(f"INDI no disponible ({e})")
        state["indi_ok"] = False
        camera_ready.clear()
        _indi_writer = None
        push_state()
        log("Reintentando INDI en 30s...")
        await asyncio.sleep(30)

async def _camera_connect_watchdog():
    await asyncio.sleep(30)
    while state["indi_ok"] and not camera_ready.is_set():
        log("SX-825 sin respuesta — reintentando CONNECTION=CONNECT...")
        _connect_camera()
        await asyncio.sleep(30)

async def _indi_read_loop(reader: asyncio.StreamReader):
    buf = ""
    while True:
        try:
            chunk = await reader.read(8192)
            if not chunk:
                break
            buf += chunk.decode(errors="ignore")

            if not camera_ready.is_set() and 'name="CONNECT">On' in buf:
                camera_ready.set()
                log("SX-825 conectada a INDI ✓")
                push_state()

            while "CCD_TEMPERATURE_VALUE" in buf:
                i       = buf.find("CCD_TEMPERATURE_VALUE")
                end_tag = buf.find("</oneNumber>", i)
                if end_tag == -1:
                    break
                segment = buf[i:end_tag]
                buf     = buf[end_tag + 12:]
                try:
                    t = round(float(segment.split(">")[-1].strip()), 1)
                    state["temperature"] = t
                    if not camera_ready.is_set():
                        camera_ready.set()
                        log(f"SX-825 lista ✓ (T={t}°C)")
                    push_state()
                except Exception:
                    pass

            if ('name="DISCONNECT">On' in buf
                    or ('name="CONNECT">Off' in buf and camera_ready.is_set())):
                camera_ready.clear()
                state["temperature"] = None
                push_state()
                log("⚠ SX-825 desconectada")
                buf = buf.replace('name="DISCONNECT">On', '').replace('name="CONNECT">Off', '')

            if len(buf) > 1_000_000:
                buf = buf[-50_000:]
        except Exception as e:
            log(f"Error leyendo INDI: {e}")
            break

def _indi_send(xml: str):
    if _indi_writer and not _indi_writer.is_closing():
        _indi_writer.write((xml + "\n").encode())

def set_number(prop: str, element: str, value: float):
    _indi_send(
        f'<newNumberVector device="{DEVICE_ALPY}" name="{prop}">'
        f'<oneNumber name="{element}">{value}</oneNumber>'
        f'</newNumberVector>'
    )

def _connect_camera():
    _indi_send(
        f'<newSwitchVector device="{DEVICE_ALPY}" name="CONNECTION">'
        f'<oneSwitch name="CONNECT">On</oneSwitch>'
        f'<oneSwitch name="DISCONNECT">Off</oneSwitch>'
        f'</newSwitchVector>'
    )

_web_app: INDIWebApp | None = None

async def _enable_blobs():
    await asyncio.sleep(4)
    try:
        await _web_app.client.xml_to_indiserver('<getProperties version="1.7"/>')
        await _web_app.client.xml_to_indiserver(
            f'<enableBLOB device="{DEVICE_ALPY}">Also</enableBLOB>'
        )
        log("BLOBs SX-825 habilitados ✓")
    except Exception as e:
        log(f"Error habilitando BLOBs: {e}")

# ── Tiempo ────────────────────────────────────────────────────────────────────
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

# ── Loop de captura ALPY ──────────────────────────────────────────────────────
async def alpy_capture_loop():
    stop_alpy_event.clear()
    state.update(alpy_running=True, alpy_status="cooling", alpy_count=0)
    push_state()
    log("=== Iniciando secuencia ALPY ===")

    start_dt    = get_start_datetime()
    wait_secs   = 0 if _in_capture_window() else (start_dt - datetime.now()).total_seconds()
    if wait_secs > 60:
        log(f"Esperando hora de inicio {params['start_time']} ({int(wait_secs//60)} min)...")
        _powered_on = False
        while not stop_alpy_event.is_set():
            remaining = (start_dt - datetime.now()).total_seconds()
            if remaining <= 0:
                break
            if not _powered_on and remaining <= 5 * 60:
                log("Encendiendo cámaras (5 min antes de inicio)...")
                await _run_power("on", ["alpy", "nikon"])
                await asyncio.sleep(15)
                if _start_nikon_too and not state["nikon_running"]:
                    asyncio.ensure_future(start_nikon())
                _powered_on = True
            await asyncio.sleep(min(30, remaining))
        if stop_alpy_event.is_set():
            await _shutdown_alpy()
            return
    else:
        # Ya en ventana activa (inicio inmediato o recuperación tras reinicio)
        log("En ventana activa — encendiendo cámaras...")
        await _run_power("on", ["alpy", "nikon"])
        await asyncio.sleep(15)

    if not camera_ready.is_set():
        log("Esperando SX-825...")
        try:
            await asyncio.wait_for(camera_ready.wait(), timeout=180)
        except asyncio.TimeoutError:
            log("Timeout conectando SX-825 — apagando cámaras.")
            await _run_power("off", ["alpy", "nikon"])
            state.update(alpy_running=False, alpy_status="idle")
            push_state()
            return

    tgt = params["target_temp"]
    log(f"Enfriando a {tgt}°C...")
    set_number("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", tgt)
    for _ in range(120):
        if stop_alpy_event.is_set():
            break
        t = state["temperature"]
        if t is not None and abs(t - tgt) <= 0.5:
            log(f"Temperatura estabilizada en {t:.1f}°C ✓")
            break
        await asyncio.sleep(5)

    if stop_alpy_event.is_set():
        await _shutdown_alpy()
        return

    state["alpy_status"] = "capturing"
    push_state()
    end_dt = get_end_datetime()
    log(f"Capturando hasta {params['end_time']} ({end_dt.strftime('%Y-%m-%d %H:%M')})")

    while not stop_alpy_event.is_set() and datetime.now() < end_dt:
        exp   = params["alpy_exposure"]
        delay = params.get("alpy_delay", 300.0)

        log(f"Exponiendo {exp}s...")
        image_event.clear()
        set_number("CCD_EXPOSURE", "CCD_EXPOSURE_VALUE", exp)
        try:
            await asyncio.wait_for(asyncio.shield(image_event.wait()), timeout=exp + 60)
            log("Imagen ALPY recibida ✓")
        except asyncio.TimeoutError:
            log("⚠ Timeout imagen ALPY")

        if stop_alpy_event.is_set() or datetime.now() >= end_dt:
            break

        if delay > 0:
            log(f"Pausa {int(delay)}s...")
            end_pause = datetime.now().timestamp() + delay
            while not stop_alpy_event.is_set() and datetime.now().timestamp() < end_pause and datetime.now() < end_dt:
                await asyncio.sleep(1)

    await _shutdown_alpy()

async def _shutdown_alpy():
    state.update(alpy_running=False, alpy_status="stopping")
    stop_alpy_event.set()
    push_state()
    log("Calentando SX-825...")
    set_number("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", 20.0)
    if state["nikon_running"]:
        await stop_nikon()
    await asyncio.sleep(3)
    log("Apagando cámaras ALPY y Nikon...")
    await _run_power("off", ["alpy", "nikon"])
    state["alpy_status"] = "idle"
    push_state()
    log("=== Secuencia ALPY finalizada ===")

# ── Nikon ─────────────────────────────────────────────────────────────────────
_nikon_proc: asyncio.subprocess.Process | None = None
_nikon_should_run = False   # True mientras nikon.sh debe estar corriendo

async def start_nikon(wait_secs: int | None = None):
    global _nikon_proc, _nikon_should_run
    if _nikon_proc and _nikon_proc.returncode is None:
        log("[Nikon] ya corriendo")
        return
    _nikon_should_run = True
    shutter   = _secs_to_shutter(params.get("nikon_exposure", 10.0))
    iso       = str(int(params.get("nikon_iso", 800)))
    interval  = str(int(params.get("alpy_delay", 300)))
    if wait_secs is None:
        if _in_capture_window():
            wait_secs = 0
        else:
            start_dt  = get_start_datetime()
            wait_secs = max(0, int((start_dt - datetime.now()).total_seconds()))
            if wait_secs < 60:
                wait_secs = 0
    log(f"[Nikon] arrancando nikon.sh — shutter={shutter} ISO={iso} INTERVAL={interval}s wait={wait_secs}s")
    _nikon_proc = await asyncio.create_subprocess_exec(
        "bash", str(NIKON_SCRIPT), shutter, iso, interval, str(wait_secs),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    state.update(nikon_running=True, nikon_count=0)
    push_state()
    asyncio.ensure_future(_nikon_monitor())

async def _nikon_monitor():
    while _nikon_proc and _nikon_proc.returncode is None:
        try:
            line = await asyncio.wait_for(_nikon_proc.stdout.readline(), timeout=5)
            if not line:
                break
            text = line.decode(errors="ignore").strip()
            if text:
                log(f"[Nikon] {text}")
                if "[OK] Guardada:" in text:
                    state["nikon_count"] += 1
                    push_state()
                    asyncio.ensure_future(_update_nikon_preview())
        except asyncio.TimeoutError:
            continue
        except Exception:
            break
    state["nikon_running"] = False
    push_state()
    log("[Nikon] proceso terminado")

async def stop_nikon():
    global _nikon_proc, _nikon_should_run
    _nikon_should_run = False
    if _nikon_proc and _nikon_proc.returncode is None:
        try:
            _nikon_proc.send_signal(signal.SIGUSR1)
            log("[Nikon] señal de parada enviada (SIGUSR1)")
        except Exception:
            pass
    state["nikon_running"] = False
    push_state()

async def _nikon_watchdog():
    """Relanza nikon.sh si muere mientras ALPY sigue en sesión activa."""
    while True:
        await asyncio.sleep(60)
        if (
            _nikon_should_run
            and state["alpy_running"]
            and not state["nikon_running"]
            and (_nikon_proc is None or _nikon_proc.returncode is not None)
        ):
            log("[Nikon] Watchdog: proceso muerto, relanzando...")
            asyncio.ensure_future(start_nikon(wait_secs=0))

def _secs_to_shutter(secs: float) -> str:
    """Convierte segundos a formato gphoto2 con coma decimal (ej. 10,0000s)."""
    return f"{secs:.4f}".replace(".", ",") + "s"

async def nikon_single(exposure: float = 10.0, iso: int = 800):
    """Disparo único configurado — solo cuando nikon.sh no está corriendo."""
    if state["nikon_running"]:
        log("[Nikon] No se puede disparar: modo continuo activo")
        return
    ts   = datetime.now().strftime("%Y%m%dT%H%M%S")
    path = UI_NIKON_DIR / f"{ts}.NEF"
    shutter = _secs_to_shutter(exposure)
    log(f"[Nikon] Captura rápida — exp={shutter} ISO={iso} → {path.name}")
    try:
        # Matar gvfs para evitar conflictos
        for proc_name in ("gvfsd-gphoto2", "gvfs-mtp-volume-monitor"):
            p = await asyncio.create_subprocess_exec(
                "pkill", "-f", proc_name,
                stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL,
            )
            await p.wait()
        await asyncio.sleep(1)

        # Configurar cámara
        for cfg_args in [
            ["--set-config", "capturetarget=0"],
            ["--set-config", f"shutterspeed={shutter}"],
            ["--set-config", f"iso={iso}"],
        ]:
            p = await asyncio.create_subprocess_exec(
                "gphoto2", *cfg_args,
                stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL,
            )
            await asyncio.wait_for(p.wait(), timeout=8)

        # Capturar
        proc = await asyncio.create_subprocess_exec(
            "gphoto2", "--capture-image-and-download", "--filename", str(path),
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=exposure + 60)
        out = stdout.decode(errors="ignore").strip()
        if proc.returncode == 0 and path.exists():
            state["nikon_count"] += 1
            push_state()
            log(f"[Nikon] Guardada: {path.name}")
            asyncio.ensure_future(_update_nikon_preview())
        else:
            log(f"[Nikon] Error en disparo: {out}")
    except asyncio.TimeoutError:
        log("[Nikon] Timeout en captura rápida")
    except Exception as e:
        log(f"[Nikon] Error: {e}")

# ── Planificador diario ───────────────────────────────────────────────────────
async def daily_scheduler():
    global _last_auto_start_date
    await asyncio.sleep(15)
    if params.get("auto_start", True) and _in_capture_window():
        log("Recuperación tras reinicio — iniciando en ventana activa...")
        if not state["alpy_running"] and state["indi_ok"]:
            _start_nikon_too = False  # recovery: Nikon se lanza directamente abajo
            asyncio.ensure_future(alpy_capture_loop())
        if not state["nikon_running"]:
            asyncio.ensure_future(start_nikon(wait_secs=0))
    while True:
        await asyncio.sleep(30)
        if not params.get("auto_start", True):
            continue
        now = datetime.now()
        sh, sm  = map(int, params["start_time"].split(":"))
        start_t = now.replace(hour=sh, minute=sm, second=0, microsecond=0)
        diff    = (now - start_t).total_seconds()
        if 0 <= diff < 300:
            today_key = now.date().isoformat()
            if _last_auto_start_date != today_key:
                _last_auto_start_date = today_key
                log(f"Auto-inicio ({params['start_time']})...")
                if not state["alpy_running"] and state["indi_ok"]:
                    _start_nikon_too = True
                    asyncio.ensure_future(alpy_capture_loop())
                    if not state["nikon_running"]:
                        asyncio.ensure_future(start_nikon())

# ── Handlers HTTP ─────────────────────────────────────────────────────────────
class MainHandler(INDIHandler):
    def get_current_user(self):
        return self.get_secure_cookie("session")

    @tornado.web.authenticated
    def get(self):
        self.indi_render(HERE / "index.html", title="ALPY + Nikon Control")


class FilesHandler(BaseHandler):
    @tornado.web.authenticated
    def get(self):
        self.set_header("Content-Type", "application/json")
        target = self.get_argument("dir", "alpy")
        d = UI_ALPY_DIR if target == "alpy" else UI_NIKON_DIR
        try:
            files = sorted(d.iterdir(), key=lambda f: f.stat().st_mtime, reverse=True)
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
        name   = self.get_argument("name", "")
        target = self.get_argument("dir", "alpy")
        d      = UI_ALPY_DIR if target == "alpy" else UI_NIKON_DIR
        path   = d / Path(name).name
        if path.exists() and path.parent.resolve() == d.resolve():
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
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            )
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


class NikonPreviewHandler(BaseHandler):
    @tornado.web.authenticated
    async def get(self):
        nefs = sorted(NIKONFILE_DIR.glob("*.NEF"), key=lambda f: f.stat().st_mtime, reverse=True)
        if not nefs:
            self.set_status(404)
            return
        loop = asyncio.get_event_loop()
        jpeg = await loop.run_in_executor(None, extract_nef_preview, nefs[0])
        if not jpeg:
            self.set_status(404)
            return
        self.set_header("Content-Type", "image/jpeg")
        self.set_header("Cache-Control", "no-cache")
        self.write(jpeg)


class CtrlWS(tornado.websocket.WebSocketHandler):
    def open(self):
        if not self.get_secure_cookie("session"):
            self.close(code=4001, reason="Unauthorized")
            return
        ws_clients.add(self)
        self.write_message(json.dumps({
            "type":          "init",
            "state":         state,
            "params":        params,
            "preview":       alpy_preview,
            "nikon_preview": nikon_preview,
            "log":           _log_entries[-100:],
        }))

    def on_message(self, raw: str):
        try:
            data = json.loads(raw)
        except Exception:
            return
        cmd = data.get("cmd")

        if cmd == "alpy_start":
            if not state["alpy_running"]:
                global _start_nikon_too
                p = data.get("params", {})
                if p:
                    params.update(p)
                    _save_params()
                _start_nikon_too = data.get("with_nikon", False)
                asyncio.ensure_future(alpy_capture_loop())

        elif cmd == "alpy_stop":
            if state["alpy_running"]:
                stop_alpy_event.set()
                log("Detención ALPY solicitada...")

        elif cmd == "alpy_abort":
            stop_alpy_event.set()
            _indi_send(
                f'<newSwitchVector device="{DEVICE_ALPY}" name="CCD_ABORT_EXPOSURE">'
                f'<oneSwitch name="ABORT">On</oneSwitch></newSwitchVector>'
            )
            state.update(alpy_running=False, alpy_status="idle")
            push_state()
            log("Captura ALPY abortada")

        elif cmd == "alpy_single":
            exp = data.get("exposure", params["alpy_exposure"])
            asyncio.ensure_future(_alpy_single(exp))

        elif cmd == "nikon_start":
            asyncio.ensure_future(start_nikon())

        elif cmd == "nikon_stop":
            asyncio.ensure_future(stop_nikon())

        elif cmd == "nikon_single":
            exp = float(data.get("exposure", params.get("nikon_exposure", 10.0)))
            iso = int(data.get("iso", params.get("nikon_iso", 800)))
            asyncio.ensure_future(nikon_single(exp, iso))

        elif cmd == "cool":
            tgt = data.get("temp", params["target_temp"])
            set_number("CCD_TEMPERATURE", "CCD_TEMPERATURE_VALUE", tgt)
            log(f"Temperatura SX-825 → {tgt}°C")

        elif cmd == "params":
            params.update(data.get("params", {}))
            _save_params()
            log("Parámetros actualizados")

        elif cmd == "power":
            action  = data.get("action", "off")
            devices = data.get("devices", [])
            asyncio.ensure_future(_run_power(action, devices))

    def on_close(self):
        ws_clients.discard(self)

    def check_origin(self, origin):
        return True


async def _alpy_single(exp: float):
    global _next_save_dir
    if not camera_ready.is_set():
        log("Esperando SX-825...")
        try:
            await asyncio.wait_for(camera_ready.wait(), timeout=30)
        except asyncio.TimeoutError:
            log("⚠ Timeout — ¿indiserver corriendo?")
            return
    _next_save_dir = UI_ALPY_DIR
    log(f"Captura rápida ALPY: {exp}s → UI/ALPY")
    image_event.clear()
    set_number("CCD_EXPOSURE", "CCD_EXPOSURE_VALUE", exp)
    try:
        await asyncio.wait_for(asyncio.shield(image_event.wait()), timeout=exp + 30)
        log("Captura rápida ALPY completada ✓")
    except asyncio.TimeoutError:
        _next_save_dir = None
        log("⚠ Timeout captura rápida ALPY")


async def _run_power(action: str, devices: list):
    if action not in ("on", "off") or not devices:
        return
    try:
        proc = await asyncio.create_subprocess_exec(
            str(CAMERA_ON_OFF), action, *devices,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=15)
        out = stdout.decode(errors="ignore").strip()
        log(f"[Power] {action} {' '.join(devices)}: {out or 'ok'}")
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
            ["bash", "-c", "sleep 2 && systemctl --user restart alpy-control"],
            start_new_session=True,
        )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    ALPYFILE_DIR.mkdir(parents=True, exist_ok=True)
    NIKONFILE_DIR.mkdir(parents=True, exist_ok=True)
    UI_ALPY_DIR.mkdir(parents=True, exist_ok=True)
    UI_NIKON_DIR.mkdir(parents=True, exist_ok=True)

    loop = tornado.ioloop.IOLoop.current()
    loop.spawn_callback(indi_connect)
    loop.spawn_callback(daily_scheduler)
    loop.spawn_callback(_nikon_watchdog)
    loop.spawn_callback(_power_status_poller)

    _web_app = INDIWebApp(
        webport=WEBPORT,
        indihost=INDIHOST,
        indiport=INDIPORT,
        handle_blob=handle_blob,
    )
    if not AUTH_FILE.exists():
        AUTH_FILE.write_text("indicatic")
        logging.info(f"Auth creado con contraseña por defecto en {AUTH_FILE}")

    logging.info(f"ALPY Control arrancando en http://0.0.0.0:{WEBPORT}")
    _web_app.build_app(
        [
            (r"/login",         LoginHandler),
            (r"/",              MainHandler),
            (r"/ws",            CtrlWS),
            (r"/files",         FilesHandler),
            (r"/delete",        DeleteHandler),
            (r"/power",         PowerHandler),
            (r"/nikon_preview", NikonPreviewHandler),
            (r"/restart",       RestartHandler),
        ],
        cookie_secret=_cookie_secret(),
        login_url="/login",
    )
