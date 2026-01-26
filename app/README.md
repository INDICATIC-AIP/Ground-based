# Ground Station Monitoring System

A comprehensive monitoring and control system for astronomical ground stations equipped with multiple cameras (ALPY, QHY, Nikon) communicating via MQTT and remotely manageable through SSH.

## Overview

This system provides real-time monitoring and control for astronomical observation stations (Jetson Orin Nano-based) equipped with:
- **ALPY 600** spectrograph camera
- **QHY 16200A** CCD camera
- **Nikon D5600** DSLR camera
- **TESS-W/TESS-W4C** photometers

The architecture consists of:
- **Remote Stations** (Jetson devices) running camera monitoring scripts
- **MQTT Brokers** for bidirectional communication (laptop and server)
- **Control UI** (Textual-based TUI) for centralized monitoring and management
- **Smart Power Strip** (TP-Link Kasa) for remote power management

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Ground Station (Jetson)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ ALPY Monitor │  │  QHY Monitor │  │ Nikon Monitor│      │
│  │ (alpy_*.sh)  │  │  (qhy_*.sh)  │  │(camera_*.sh) │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                            │                                 │
│                   ┌────────▼────────┐                        │
│                   │ status_cameras  │ (USB monitoring)       │
│                   │  CheckConnections│ (health checks)       │
│                   └────────┬────────┘                        │
│                            │                                 │
│                   ┌────────▼────────┐                        │
│                   │   MQTT Publish  │                        │
│                   └────────┬────────┘                        │
└────────────────────────────┼────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  MQTT Brokers   │
                    │ (Laptop/Server) │
                    └────────┬────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                    Control Station (UI)                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            Textual UI (ui.py)                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐     │   │
│  │  │  Station   │  │   Camera   │  │   Logs     │     │   │
│  │  │  Overview  │  │   Status   │  │  Viewer    │     │   │
│  │  └────────────┘  └────────────┘  └────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │      Data Manager (subscriber2.py)                   │   │
│  │      - MQTT Subscription                             │   │
│  │      - Camera State Management                       │   │
│  │      - Event Processing                              │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │      SSH Command Module (ssh_comand.py)              │   │
│  │      - Remote camera control                         │   │
│  │      - Power management                              │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

## MQTT Topic Structure

The system uses a hierarchical topic structure:

```
<station_name>/<camera_type>/<event_type>
```

### Topics by Camera

**ALPY Camera:**
- `{station}/alpy/status` - Connection status
- `{station}/alpy/temperature_update` - Temperature readings
- `{station}/alpy/capture_start` - Capture initiation
- `{station}/alpy/capture_complete` - Capture completion with metadata
- `{station}/alpy/files` - List of captured FITS files
- `{station}/alpy/heartbeat` - Keep-alive signal

**QHY Camera:**
- `{station}/qhy/status` - Connection status
- `{station}/qhy/temperature_update` - Temperature readings
- `{station}/qhy/capture_start` - Capture initiation
- `{station}/qhy/capture_complete` - Capture completion with metadata
- `{station}/qhy/files` - List of captured FITS files
- `{station}/qhy/heartbeat` - Keep-alive signal

**Nikon Camera:**
- `{station}/nikon/status` - Connection status
- `{station}/nikon/files` - List of captured NEF files
- `{station}/nikon/heartbeat` - Keep-alive signal

### Message Formats

**Connection Status:**
```json
{
  "status": true|false
}
```

**Temperature Update:**
```json
{
  "temperature": -10.5
}
```

**Capture Start:**
```json
{
  "exposure_time": 10000000
}
```

**Capture Complete:**
```json
{
  "filename": "/path/to/image.fits",
  "time": "2025-12-04T12:30:45",
  "temperature": -10.2
}
```

**Files List:**
```json
[
  {
    "filepath": "/path/to/file1.fits",
    "filesize": 33554432
  },
  {
    "filepath": "/path/to/file2.fits",
    "filesize": 33554432
  }
]
```

## Components

### 1. Station-Side Scripts (Jetson)

#### `config.sh`
Central configuration file loaded by all monitoring scripts:
- MQTT broker addresses (laptop and server)
- Credentials per broker (using `.env` file)
- Topic definitions for each camera
- Logging paths
- Utility functions: `send_mqtt()`, `log_message()`

#### `alpy_monitor.sh`
Monitors ALPY spectrograph camera:
- Sends temperature updates
- Reports capture start events
- Logs capture completion with metadata
- **Usage:**
  ```bash
  ./alpy_monitor.sh temperature_update -10.5
  ./alpy_monitor.sh capture_start 10000000
  ./alpy_monitor.sh capture_complete /path/file.fits "2025-12-04T12:30:45" -10.2
  ```

#### `qhy_monitor.sh`
Monitors QHY CCD camera:
- Same functionality as ALPY monitor
- Adapted for QHY-specific topics and data
- **Usage:** Same pattern as `alpy_monitor.sh`

#### `status_cameras.sh`
Unified camera monitoring daemon:
- Continuously monitors USB connections (`lsusb`)
- Detects camera presence/disconnection
- Sends periodic status updates via MQTT
- Lists captured files and publishes via MQTT
- Sends heartbeat signals every 10 seconds
- **Modes:**
  ```bash
  ./status_cameras.sh 1        # Start monitoring daemon
  ./status_cameras.sh 2        # Stop daemon
  ./status_cameras.sh status   # Check daemon status
  ```
- **PID Management:** Uses `/tmp/status_cameras.pid` to prevent multiple instances

#### `camera_on_off.sh`
Controls camera power via TP-Link Kasa smart strip:
- **Usage:**
  ```bash
  ./camera_on_off.sh on alpy qhy        # Turn on ALPY and QHY
  ./camera_on_off.sh off nikon          # Turn off Nikon
  ./camera_on_off.sh on alpy qhy nikon  # Turn on all cameras
  ```
- **Device Mapping:**
  - `alpy` → Index 0
  - `qhy` → Index 1
  - `nikon` → Index 2

#### `strip_status.sh`
Queries power strip outlet status:
- **Usage:**
  ```bash
  ./strip_status.sh alpy    # Returns: on|off|error
  ./strip_status.sh qhy
  ./strip_status.sh nikon
  ```

#### `CheckConnections.sh`
Periodic health check script:
- Verifies USB driver presence for each camera
- Sends email alerts if cameras are disconnected
- Integrates with `SendMail.sh` from AutoRun folder

### 2. Control Station (UI)

#### `ui.py`
Main Textual-based TUI application:
- **Features:**
  - Multi-station monitoring in tabbed interface
  - Real-time camera status display (connection, temperature)
  - Image capture logs viewer
  - Remote camera power control (on/off via SSH)
  - Station switching with keyboard shortcuts
- **Key Bindings:**
  - `q` - Quit application
  - `s` - Next station
  - `f` - Next camera tab
  - `a` - Show camera shutdown dialog
- **Configuration:** Uses `.env` file for:
  - MQTT broker addresses and credentials
  - SSH credentials for each station

#### `subscriber2.py`
MQTT data management backend:
- **Classes:**
  - `BaseCamera` - Base class for all camera types
  - `AlpyCamera` - ALPY-specific with temperature tracking
  - `QHYCamera` - QHY-specific with temperature tracking
  - `NikonCamera` - Nikon-specific implementation
  - `TessCamera` - TESS photometer implementation
  - `AstroDataManager` - Centralized state manager
- **Functionality:**
  - Subscribes to all MQTT topics (`+/+/+`)
  - Parses and routes messages to appropriate camera objects
  - Maintains camera state and logs
  - Tracks heartbeats for connection timeout detection
  - Provides unified interface for UI

#### `ssh_comand.py`
SSH command execution module:
- Executes remote commands via Paramiko
- Used for camera power control
- Returns stdout, stderr, and exit status
- **Usage:**
  ```python
  output, error, status = send_ssh_command(
      hostname="192.168.1.100",
      username="user",
      password="pass",
      command="./camera_on_off.sh off alpy"
  )
  ```

#### `astroUI.tcss`
Textual CSS stylesheet for UI theming and layout.

### 3. Camera Control Code (INDIcode)

#### `indi.cpp`
ALPY camera control via INDI framework:
- Connects to INDI server (localhost:7624)
- Controls Starlight Xpress CCD (ALPY)
- Sets target temperature and monitors cooling
- Automated capture loop with configurable exposure and intervals
- Temperature alert system with email notifications
- Emergency shutdown on overheating
- Signal handling for graceful termination (SIGUSR1)
- **Configuration:**
  - `ExpositionTime` - Exposure duration (seconds)
  - `Offset` - Time between captures (seconds)
  - `TargetedTemp` - Target cooling temperature (°C)
  - `AlertTemp` - Alert threshold temperature (°C)

#### `qhy_ccd_test.cpp`
QHY camera control using QHY SDK:
- Direct SDK control of QHY 16200A
- Filter wheel control (CFW)
- Automated multi-filter capture sequences
- Temperature regulation and monitoring
- USB traffic and gain/offset configuration
- FITS file generation with metadata
- Signal handling for clean shutdown
- **Configuration:**
  - `USB_TRAFFIC` - USB bandwidth (default: 10)
  - `CHIP_GAIN` - Sensor gain (default: 10)
  - `CHIP_OFFSET` - Sensor offset (default: 140)
  - `EXPOSURE_TIME` - Exposure in microseconds
  - `TargetedTemp` - Target temperature (°C)

## System Workflow

### 1. Station Startup Sequence

1. **Initialize Environment:**
   ```bash
   # Source configuration
   source /path/to/.env
   source /path/to/config.sh
   ```

2. **Start Camera Monitoring:**
   ```bash
   ./status_cameras.sh 1
   ```

3. **Start Camera Control Programs:**
   ```bash
   # ALPY via INDI
   ./indi
   
   # QHY via SDK
   ./qhy_ccd_test
   ```

4. **Health Monitoring:**
   ```bash
   # Add to crontab for periodic checks
   */15 * * * * /path/to/CheckConnections.sh
   ```

### 2. Data Flow

```
Camera Event → Monitor Script → MQTT Publish → Broker → UI Subscribe → Update Display
     ↓                                                                        ↓
USB Detection → status_cameras.sh → File List → MQTT → Data Manager → Camera Object
```

### 3. Remote Control Flow

```
UI User Action → SSH Command → Station → camera_on_off.sh → Kasa Strip → Power On/Off
```

## Requirements

### Station (Jetson Orin Nano)

**System:**
- Ubuntu 20.04/22.04 (JetPack)
- Bash shell

**Software:**
- MQTT client: `mosquitto-clients`
- Python 3.8+
- INDI server and libraries
- QHY SDK
- TP-Link Kasa CLI: `python-kasa`
- USB utilities: `usbutils`

**Hardware:**
- Jetson Orin Nano Developer Kit
- TP-Link Kasa smart power strip
- Cameras: ALPY 600, QHY 16200A, Nikon D5600

### Control Station

**System:**
- Linux
- Python 3.8+

**Python Packages:**
```bash
pip install paho-mqtt paramiko textual python-dotenv
```

**MQTT Broker:**
```bash
# Debian/Ubuntu
sudo apt update
sudo apt install -y mosquitto mosquitto-clients

# macOS
brew install mosquitto
```

## Installation

### 1. MQTT Broker Setup

**Mosquitto Configuration** (`/etc/mosquitto/mosquitto.conf`):
```conf
# Production configuration
listener 1883
allow_anonymous false
password_file /etc/mosquitto/passwd

```

**Create Users:**
```bash
sudo mosquitto_passwd -c /etc/mosquitto/passwd laptop_user
sudo mosquitto_passwd /etc/mosquitto/passwd server_user
sudo systemctl restart mosquitto
```

### 2. Station Setup

1. **Clone Repository:**
   ```bash
   git clone https://github.com/INDICATIC-AIP/Ground-base.git
   cd Ground-base
   ```

2. **Configure Environment Variables:**
   Create `.env` file in home directory:
   ```bash
   # MQTT Configuration example
   LAPTOP_BROKER_IP=192.168.1.100
   SERVER_BROKER_IP=10.0.0.50
   MQTT_PORT=1883
   LAPTOP_USER=laptop_user
   LAPTOP_PASSWORD=laptop_pass
   SERVER_USER=server_user
   SERVER_PASSWORD=server_pass
   
   # Jetson Identification
   JETSON_NAME=indicatic
   
   # Smart Strip Configuration
   STRIP_IP=192.168.1.200
   STRIP_USER=admin@email.com
   STRIP_PASSWORD=strip_password
   
   # SSH Credentials (for UI)
   INDICATIC_SSH_USER=indicatic-e1
   INDICATIC_SSH_HOST=192.168.1.101
   INDICATIC_SSH_PASSWORD=ssh_password
   ```

3. **Install Python Dependencies:**
   ```bash
   pip install python-kasa paho-mqtt
   ```

4. **Make Scripts Executable:**
   ```bash
   chmod +x app/*.sh
   ```

5. **Update Path References:**
   ```bash
   # Run station rename script
   python3 station_rename.py
   ```

6. **Start Monitoring:**
   ```bash
   cd app
   ./status_cameras.sh 1
   ```

### 3. Control Station Setup

1. **Install Dependencies:**
   ```bash
   pip install paho-mqtt paramiko textual python-dotenv
   ```

2. **Configure `.env` File:**
   Copy and modify the `.env` template with your credentials.

3. **Run UI:**
   ```bash
   cd app
   python3 ui.py
   ```

## Configuration Files

### `.env` Structure
```ini
# MQTT Brokers
LAPTOP_BROKER_IP=<ip_address>
SERVER_BROKER_IP=<ip_address>
MQTT_PORT=1883
LAPTOP_USER=<username>
LAPTOP_PASSWORD=<password>
SERVER_USER=<username>
SERVER_PASSWORD=<password>

# Station Identity
JETSON_NAME=<station_name>

# Power Control
STRIP_IP=<kasa_strip_ip>
STRIP_USER=<kasa_email>
STRIP_PASSWORD=<kasa_password>

# SSH Access (per station)
INDICATIC_SSH_USER=<username>
INDICATIC_SSH_HOST=<hostname_or_ip>
INDICATIC_SSH_PASSWORD=<password>

INDICATICE2_SSH_USER=<username>
INDICATICE2_SSH_HOST=<hostname_or_ip>
INDICATICE2_SSH_PASSWORD=<password>
```

### `config.sh` Key Variables
```bash
# Automatically loaded from .env
MQTT_BROKERS=("$LAPTOP" "$SERVER")
MQTT_PORT=1883
JETSON_NAME="${JETSON_NAME:-$(hostname)}"

# Topics
ALPY_TOPIC_BASE="alpy"
QHY_TOPIC_BASE="qhy"
NIKON_TOPIC_BASE="nikon"

# Logs
ALPY_LOG="/tmp/alpyMQTT.txt"
QHY_LOG="/tmp/qhyMQTT.txt"
CAMERAS_LOG="/tmp/camerasMQTT.txt"
```

## Logging

### Log Files (Station)
- `/tmp/alpyMQTT.txt` - ALPY MQTT events
- `/tmp/qhyMQTT.txt` - QHY MQTT events
- `/tmp/camerasMQTT.txt` - Camera status monitoring
- `/tmp/status_cameras.txt` - Daemon output

### Log Files (Control Station)
- `astroUI.log` - UI application events (rotating, 1MB max, 3 backups)

### Log Format
```
[2025-12-04 12:30:45] [INFO] Sent to indicatic/alpy/temperature_update: {"temperature":-10.5}
```

## Troubleshooting

### Camera Not Detected

1. **Check USB Connection:**
   ```bash
   lsusb
   # Look for: Starlight Xpress, Terminus Technology, Nikon Corp.
   ```

2. **Check Monitoring Status:**
   ```bash
   ./status_cameras.sh status
   ```

3. **Review Logs:**
   ```bash
   tail -f /tmp/camerasMQTT.txt
   ```

### MQTT Connection Issues

1. **Test Broker Connectivity:**
   ```bash
   mosquitto_pub -h <broker_ip> -u <user> -P <password> -t test -m "hello"
   ```

2. **Check Broker Status:**
   ```bash
   sudo systemctl status mosquitto
   ```

3. **Monitor MQTT Traffic:**
   ```bash
   mosquitto_sub -h <broker_ip> -u <user> -P <password> -t '#' -v
   ```

### Power Control Not Working

1. **Test Kasa Connection:**
   ```bash
   kasa --type strip --host $STRIP_IP --username $STRIP_USER --password $STRIP_PASSWORD
   ```

2. **Verify Strip Status:**
   ```bash
   ./strip_status.sh alpy
   # Should return: on|off|error
   ```

### Temperature Issues

1. **Check INDI Connection (ALPY):**
   ```bash
   indi_getprop "SX CCD SX-825.CCD_TEMPERATURE.CCD_TEMPERATURE_VALUE"
   ```

2. **Monitor Temperature Logs:**
   ```bash
   grep -i temperature /tmp/alpyMQTT.txt
   ```

### UI Not Updating

1. **Verify MQTT Subscription:**
   - Check UI logs for connection errors
   - Ensure broker credentials are correct

2. **Test Data Manager:**
   ```python
   from subscriber2 import AstroDataManager
   dm = AstroDataManager()
   dm.start_mqtt(broker="<ip>", username="<user>", password="<pass>")
   # Check for connection messages
   ```

## Security Considerations

- **Never expose MQTT broker without authentication** on public networks
- **Use TLS/SSL** for MQTT connections in production
- **Rotate SSH credentials** periodically
- **Use SSH keys** instead of passwords where possible
- **Restrict firewall rules** to known IP ranges
- **Store `.env` files securely** with proper permissions:
  ```bash
  chmod 600 ~/.env
  ```

## Performance Optimization

- **Log Rotation:** All logs are automatically rotated (1000 lines max)
- **MQTT QoS:** Use QoS 0 for high-frequency temperature updates
- **Daemon Management:** `status_cameras.sh` prevents multiple instances
- **Heartbeat Interval:** 10 seconds for balance between freshness and traffic

## Project Structure

```
Ground-base/
├── app/                          # Monitoring and UI
│   ├── ui.py                    # Main UI application
│   ├── subscriber2.py           # MQTT data manager
│   ├── ssh_comand.py            # SSH utilities
│   ├── config.sh                # Central configuration
│   ├── alpy_monitor.sh          # ALPY monitoring
│   ├── qhy_monitor.sh           # QHY monitoring
│   ├── status_cameras.sh        # Unified camera monitoring
│   ├── camera_on_off.sh         # Power control
│   ├── strip_status.sh          # Power status query
│   ├── CheckConnections.sh      # Health checks
│   └── astroUI.tcss             # UI stylesheet
├── INDIcode/                     # Camera control code
│   ├── indi.cpp                 # ALPY control via INDI
│   └── qhy_ccd_test.cpp         # QHY control via SDK
├── AutoRun/                      # Automation scripts
├── code/                         # Interoperability code
│   ├── Interop_code/            # Data transmission
│   └── CryptageC/               # Encryption
├── NAScode/                      # NAS-side processing
├── ASTRODEVICES/                 # Captured images
│   ├── ALPYFILE/                # ALPY FITS files
│   ├── QHYCCDFILE/              # QHY FITS files
│   └── NIKONFILE/               # Nikon NEF files
└── station_rename.py            # Path update utility
```

## Related Documentation

- [AutoRun README](../AutoRun/README.md) - Automation and scheduling
- [INDIcode README](../INDIcode/README.md) - Camera control details
- [NAScode README](../NAScode/README.md) - Server-side processing
- [code README](../code/README.md) - Interoperability and encryption

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit a pull request

## Support & Contact

For questions, issues, or contributions:
- **Email:** alexandre.olivie@bordeaux-inp.fr, jose.jaenj08@hotmail.com
- **Issues:** [GitHub Issues](https://github.com/INDICATIC-AIP/Ground-base/issues)

## License

See [LICENSE](../LICENSE) file for details.

