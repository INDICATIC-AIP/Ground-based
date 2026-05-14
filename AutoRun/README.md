# AutoRun — Observatory Control System

Web-based control system for both ground stations. Replaces the legacy KStars/Ekos/D-Bus stack with lightweight Python applications built on **pyINDI + Tornado**.

---

## Stations

Both stations are **NVIDIA Jetson** boards located at **UTP** (Estación Observatorio UTP).

| Station | Hardware | Cameras | Port |
|---|---|---|---|
| indicatice2 | Jetson | ALPY 600 (SX CCD SX-825) + Nikon D5600 | :5906 |
| indicatic-e1 | Jetson | QHY 16200A-M (UBVRI filters) | :5905 |

---

## Architecture

```
Jetson station
│
├── indiserver :7624
│     └── indi_sx_ccd  or  indi_qhy_ccd
│
├── app.py  (systemd user service, 24/7)
│     ├── pyINDI TCP connection → indiserver
│     ├── WebSocket /ws         → browser (Tornado)
│     └── index.html            → web UI
│
└── Interop pipeline (triggered per image)
      my_program (C)  →  alpy.sh / QHYCCD.sh  →  connect.sh  →  NAS
```

---

## Station 1 — indicatice2 · ALPY 600 + Nikon D5600

**Web UI:** `http://indicatice2:5906`

### Files

| File | Description |
|---|---|
| `alpy/app.py` | Web server + ALPY capture logic + Nikon control |
| `alpy/index.html` | Web UI (dark theme, single-page app) |
| `alpy/params.json` | Persistent parameters (created on first save) |
| `alpy/nikon.sh` | Nikon D5600 continuous capture via gphoto2 |

### systemd service

```ini
# ~/.config/systemd/user/alpy-control.service
[Unit]
Description=ALPY 600 + Nikon Web Control
After=network.target

[Service]
ExecStartPre=/bin/bash /home/indicatice2/Desktop/AutoRun/IndiServ.sh indi_sx_ccd "SX CCD"
ExecStart=/usr/bin/python3 /home/indicatice2/Desktop/AutoRun/alpy/app.py
WorkingDirectory=/home/indicatice2/Desktop/AutoRun/alpy
Restart=always
RestartSec=15
StandardOutput=append:/tmp/logALPY.txt
StandardError=append:/tmp/logALPY.txt

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable alpy-control
systemctl --user start alpy-control
systemctl --user status alpy-control
tail -f /tmp/logALPY.txt
```

### Daily cycle (automatic)

1. `daily_scheduler()` runs in background every 30 s, reads params from `params.json`
2. Powers on ALPY + Nikon via Kasa smart strip 5 minutes before `start_time`
3. At `start_time`: starts ALPY spectrometer capture loop
4. Also at `start_time`: launches `nikon.sh` for continuous wide-field imaging
5. At `end_time`: stops both cameras, warms CCD to 20 °C, powers off strip

### Nikon D5600 notes

- Camera dial must be set to **M** (Manual) mode for gphoto2 to control shutter/ISO
- Exposure format for gphoto2: `10,0000s` (comma as decimal separator)
- Quick capture saves to `/home/indicatice2/Desktop/ASTRODEVICES/UI/NIKON/`
- Scheduled capture saves to `/home/indicatice2/Desktop/ASTRODEVICES/NIKONFILE/`

---

## Station 2 — indicatic-e1 · QHY 16200A-M

**Web UI:** `http://indicatic-e1:5905`

### Files

| File | Description |
|---|---|
| `qhy/app.py` | Web server + QHY capture logic (UBVRI cycle) |
| `qhy/index.html` | Web UI (dark theme, single-page app) |
| `qhy/params.json` | Persistent parameters (created on first save) |

### systemd service

```ini
# ~/.config/systemd/user/qhy-control.service
[Unit]
Description=QHY 16200A Web Control
After=network.target

[Service]
ExecStartPre=/bin/bash /home/indicatic-e1/Desktop/AutoRun/IndiServ.sh indi_qhy_ccd "QHY"
ExecStart=/usr/bin/python3 /home/indicatic-e1/Desktop/AutoRun/qhy/app.py
WorkingDirectory=/home/indicatic-e1/Desktop/AutoRun/qhy
Restart=always
RestartSec=15
StandardOutput=append:/tmp/logQHY.txt
StandardError=append:/tmp/logQHY.txt

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable qhy-control
systemctl --user start qhy-control
systemctl --user status qhy-control
tail -f /tmp/logQHY.txt
```

### Daily cycle (automatic)

1. `daily_scheduler()` runs in background every 30 s, reads params from `params.json`
2. Powers on QHY via Kasa smart strip 5 minutes before `start_time`
3. At `start_time`: connects to indiserver, cools CCD to target temperature
4. Once temperature is stable (±0.5 °C): runs UBVRI filter cycle until `end_time`
5. At `end_time`: warms CCD to 20 °C, powers off strip

### UBVRI capture loop

```
for each active filter (U, B, V, R, I):
  move filter wheel → wait 45 s settle
  expose (CCD_EXPOSURE_VALUE)
  receive BLOB → save .raw + .fits → send JPEG preview to UI
```

### Output files

Each image produces two files in `/home/indicatic-e1/Desktop/ASTRODEVICES/QHYCCDFILE/`:

```
20260505T143524U.raw   ← raw uint16 pixels (no headers)
20260505T143524U.fits  ← FITS with full astronomical headers
```

FITS headers written: `DATE-OBS`, `INSTRUME`, `FILTER`, `EXPTIME`, `CCD-TEMP`, `GAIN`, `OFFSET`, `XBINNING`, `YBINNING`.

---

## Interop Pipeline (both stations)

After each image is saved, `my_program` (compiled C binary) detects the new file and triggers:

```
my_program  →  alpy.sh / QHYCCD.sh  →  connect.sh  →  NAS (SFTP via lftp)
```

Source: [`../code/Interop_code/`](../code/Interop_code/)

The pipeline checksums the file, encrypts the checksum, and verifies upload success on the NAS before deleting the local copy.

---

## Smart Strip (Kasa) — Power Control

Both stations use a TP-Link Kasa smart power strip managed by `camera_on_off.sh`:

```bash
# In app/ folder (deployed to Desktop/app/ on each station)
./camera_on_off.sh on  alpy
./camera_on_off.sh off nikon
./camera_on_off.sh on  qhy
```

The web apps call this script automatically at scheduled power-on/off times.

---

## Remote Access — Tailscale Funnel

Each station exposes its web UI over the public internet via **Tailscale Funnel**.

The `--bg` flag saves the config into `tailscaled`'s persistent state — it survives terminal disconnects and reboots without any extra systemd service.

### Setup (run once per station)

```bash
# indicatice2
sudo tailscale funnel --bg 5906

# indicatic-e1
sudo tailscale funnel --bg 5905
```

> **If you get "foreground listener already exists"**, reset first:
> ```bash
> sudo tailscale serve reset
> sudo tailscale funnel reset
> # then re-run the command above
> ```

### Verify

```bash
sudo tailscale funnel status
```

### URLs

| Station | URL |
|---|---|
| indicatice2 | `https://indicatice2.<tailnet>.ts.net` |
| indicatic-e1 | `https://indicatic-e1.<tailnet>.ts.net` |

---

## Python Dependencies

```
tornado
pyindi        # MMTObservatory/pyINDI — copy module to site-packages
astropy
Pillow
numpy
```

See `../station-requirements.txt` for the full list.
