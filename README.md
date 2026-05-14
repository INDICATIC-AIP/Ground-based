# Project Description


![Detalles completos del proyecto](./TLP_PTY.png)

TropicalALAN_Lab_PTY is a research and engineering group dedicated to advancing the understanding of artificial light at night (ALAN) in tropical environments. The team operates the first multi-station monitoring network across the Panama Canal Basin, integrating photometric, spectrometric, and remote-sensing datasets. The group develops open, interoperable software and automated hardware systems to quantify the environmental, atmospheric, biological, and economic implications of light pollution, including links with regional GDP/PIB.

## Security Notice - Encryption Implementation

**IMPORTANT:** This project uses a proprietary, deployment-specific encryption system that is intentionally not included in this public repository for security reasons.

The repository provides the interoperability framework and integration points, but the cryptographic implementation, key material, and related binaries are managed internally and are not distributed publicly.
Data transfer between stations and the NAS relies on secure transport mechanisms (e.g. SFTP over SSH), while additional integrity and authenticity checks are performed using an internal encryption and verification workflow.

Users intending to adapt this framework must integrate their own secure encryption and key-management solution appropriate to their deployment and threat model. Custom cryptographic algorithms should not be implemented without appropriate expertise.

# Interoperability Code 

The interoperability framework deployed here enables the continuous operation of the INDICATIC–UTP substation, where multiple scientific instruments are directly connected to an NVIDIA Jetson Nano for on-site control and pre-processing. Calibrated data are automatically transmitted to an institutional Network-Attached Storage (NAS). The system manages concurrent communication with multiple scientific instruments operating in parallel (docs/diagrams):

QHY 16200A (UV, B, V, R, and IR all-sky images)

Nikon D5600 (RGBI all-sky imaging)

ALPY 600 spectrometer (350 nm to 800 nm)

TESS-W/TESS-4C


1. [AutoRun](https://github.com/INDICATIC-AIP/Ground-based/tree/main/AutoRun)
2. [NAScode](https://github.com/INDICATIC-AIP/Ground-based/tree/main/NAScode)
3. [code](https://github.com/INDICATIC-AIP/Ground-based/tree/main/code)

--------------------------------------------------------------------

## Components

### [AutoRun](https://github.com/INDICATIC-AIP/Ground-based/tree/main/AutoRun)

Web-based control system for both Jetson stations, built on **pyINDI + Tornado**. Each station runs a persistent Python web app (24/7 systemd service) that controls the cameras via INDI protocol and exposes a browser UI for scheduling, monitoring, and manual control.

| Station | Cameras |
|---|---|
| indicatice2 | ALPY 600 + Nikon D5600 |
| indicatic-e1 | QHY 16200A-M (UBVRI) |

See [AutoRun/README.md](https://github.com/INDICATIC-AIP/Ground-based/tree/main/AutoRun/README.md) for full setup and operation instructions.

### [NAScode](https://github.com/INDICATIC-AIP/Ground-based/tree/main/NAScode)

Scripts that run on the institutional NAS (Synology). Handles file decryption, integrity verification, and organisation of incoming data from both stations into the archive directory structure.

### [code](https://github.com/INDICATIC-AIP/Ground-based/tree/main/code)

Station-side interoperability code. The `Interop_code/` subdirectory contains the C binary (`my_program`) and shell scripts that detect new images, generate checksums, encrypt them, and upload files to the NAS via SFTP. Also contains `converter.py` (FITS processing) and `nikon.sh` (gphoto2 wrapper for the Nikon D5600).

--------------------------------------------------------------------

# Installation Instructions

Before installation, ensure Linux is properly configured on the Jetson. Guidance:
- [Initial Setup Guide for Jetson Orin Nano](https://www.jetson-ai-lab.com/initial_setup_jon.html)

Clone the repository on the station and move the relevant folders to the Desktop:

```bash
git clone https://github.com/INDICATIC-AIP/Ground-base.git
cd Ground-base
# Rename hardcoded paths to match this station’s username:
python3 station_rename.py
# Then move to Desktop
cp -r AutoRun code app ~/Desktop/
# NAScode is for the NAS only — do not copy it to the station
```

Recommended installation order:

1. [code](https://github.com/INDICATIC-AIP/Ground-based/tree/main/code) — install dependencies, compile Interop binary
2. [AutoRun](https://github.com/INDICATIC-AIP/Ground-based/tree/main/AutoRun) — configure and start the web app as a systemd service

See [AutoRun/README.md](https://github.com/INDICATIC-AIP/Ground-based/tree/main/AutoRun/README.md) for the full systemd setup.

- **Python version tested:** Python 3.10.12 — the system has been tested with this interpreter version; using Python 3.10.12 is recommended for compatibility.

**Minimal Usage**

- **Clone:**
	- `git clone https://github.com/INDICATIC-AIP/Ground-base.git`
	- `cd Ground-base`
- **Install (example):**
	- `pip3 install -r station-requirements.txt`
	- If you need UI or NAS dependencies, also run:
		- `pip3 install -r ui-requirements.txt`
		- `pip3 install -r nas-requirements.txt`
- **Verify:**
	- `python3 --version` to confirm a Python interpreter is available.
	- `python3 -m pip check` to detect broken or missing dependencies.
	- Optionally run a non-destructive script to confirm scripts execute, for example:
		- `python3 station_rename.py --help` or `python3 station_rename.py` (review the script before running).

# Configuring the Station Name
To ensure the code uses the correct internal paths:
1. On the Desktop, open the script named station_rename.py.
2. Uncomment the following three lines:

 new_content = re.sub("indicatic-e1", "indicatice2", content)
 with open(filename, 'w', encoding='utf-8') as f:
 f.write(new_content)

Replace "indicatice2" with the actual station hostname.
Run the script:

python3 station_rename.py

whoami

# How to Cite

If you use this system or build upon it in your research, please cite it as:

```bibtex
@software{indicatic_ground_based,
  author       = {José Robles, José Jaén, Alexandre Olivie},
  title        = {{INDICATIC Ground-Based Observatory Control System}},
  year         = {2025},
  organization = {TropicalALAN Lab PTY — INDICATIC-AIP},
  url          = {https://github.com/INDICATIC-AIP/Ground-based},
}
```

Or in plain text:

> José Robles, José Jaén, Alexandre Olivie. *INDICATIC Ground-Based Observatory Control System*. TropicalALAN Lab PTY, 2025. https://github.com/INDICATIC-AIP/Ground-based

si usa los datos debe ofrecer coautoría

preguntar por que sale uncalibrated en eje y de tess 4c por que sale

# Contact Information

For scientific and technical inquiries about this project:
Dr. Jose Robles
jrobles@indicatic.org.pa

For questions about the code after reading the READMEs:
Jose Jaen
jose.jaenj08@hotmail.com
Alexandre Olivie
alexandre.olivie@bordeaux-inp.fr

For environmental communication or outreach regarding light pollution:
Alma Rivera
arivera@indicatic.org.pa
