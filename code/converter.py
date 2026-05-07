# Watches the QHYCCD FITS directory (written by Ekos) and generates a .raw
# sidecar for every new FITS file so the NAS sender receives both formats.
# Checks every 5 seconds; skips files still being written (age < 2 s).

import os
import time
import numpy as np
from astropy.io import fits

FITS_DIR = "/home/indicatic-e1/Desktop/ASTRODEVICES/QHYCCDFILE"

def extract_raw(fits_path: str) -> str:
    """Extract pixel data from a FITS file and save as .raw beside it."""
    data = fits.getdata(fits_path)
    raw_path = os.path.splitext(fits_path)[0] + ".raw"
    data.astype(np.uint16).tofile(raw_path)
    return raw_path

processed = set()

while True:
    try:
        for filename in os.listdir(FITS_DIR):
            if not filename.endswith(".fits"):
                continue

            fits_path = os.path.join(FITS_DIR, filename)

            if fits_path in processed:
                continue

            # Skip files still being written by Ekos
            if time.time() - os.path.getmtime(fits_path) < 2:
                continue

            try:
                raw_path = extract_raw(fits_path)
                processed.add(fits_path)
                print(f"RAW generated: {raw_path}")
            except Exception as e:
                print(f"Error processing {fits_path}: {e}")

    except Exception as e:
        print(f"Directory error: {e}")

    time.sleep(5)
