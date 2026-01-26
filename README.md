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
2. [INDIcode](https://github.com/INDICATIC-AIP/Ground-based/tree/main/INDIcode)
3. [NAScode](https://github.com/INDICATIC-AIP/Ground-based/tree/main/NAScode)
4. [code](https://github.com/INDICATIC-AIP/Ground-based/tree/main/code)

--------------------------------------------------------------------

## Components ("AutoRun", "INDIcode", "NAScode", and "code").

### [AutoRun](https://github.com/INDICATIC-AIP/Ground-based/tree/main/AutoRun)

This folder contains all scripts related to the automation of the stations, allowing remote control, error detection, and other operational tasks.

### [INDIcode](https://github.com/INDICATIC-AIP/Ground-based/tree/main/INDIcode)

This folder contains parts of the library sourced from the INDIGO Astronomy project: (https://github.com/indigo-astronomy/indigo/blob/master/indigo_drivers/ccd_qhy/bin_externals/qhyccd/include/qhyccd.h). These components enable the C++ scripts to function properly and control the QHY 16200A and ALPY 600 devices.

### [NAScode](https://github.com/INDICATIC-AIP/Ground-based/tree/main/NAScode)

This folder contains the scripts used to achieve interoperability on the NAS side. File decryption and organization tasks are managed here to ensure data integrity.

### [code](https://github.com/INDICATIC-AIP/Ground-based/tree/main/code)

This folder contains the interoperability scripts within the "Interop_code" directory. The "CryptageC" folder includes all encryption scripts used to secure data transmitted to the NAS.
Additional folders and .txt files serve as shared resources for determining NAS destinations, exchanging status information, and supporting interoperability processes.

--------------------------------------------------------------------

# Installation Instructions
Each folder contains a README explaining the functions of the scripts and specifying the required libraries. To fully install the interoperability code on a station, you must read and execute the instructions in all four folders.
A recommended installation order is:

1. code — https://github.com/INDICATIC-AIP/Ground-based/tree/main/code
2. INDIcode — https://github.com/INDICATIC-AIP/Ground-based/tree/main/INDIcode
3. AutoRun — https://github.com/INDICATIC-AIP/Ground-based/tree/main/AutoRun

Before installation, ensure Linux is properly installed on the Jetson system. Guidance:
1. Initial Setup Guide for Jetson Orin Nano:
2. https://www.jetson-ai-lab.com/initial_setup_jon.html
   
After cloning this repository on the station:
1. Move the folders "code", "INDIcode", and "AutoRun" to the Desktop.
2. Delete the folder "NAScode" (NAS-side only).
3. Delete the cloned folder "Ground-based" once extraction is complete.

You can now begin installation following each module’s README.

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
