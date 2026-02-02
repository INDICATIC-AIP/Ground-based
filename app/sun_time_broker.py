#!/usr/bin/env python3
"""
Script to calculate sunrise/sunset, publish the appropriate command to an MQTT broker,
and schedule the next event in cron.

Requires:
    pip install astral paho-mqtt python-dotenv

Behavior:
    - Publishes `open` or `close` to the MQTT topic `domo/command`.
    - The subscribed ESP32 will act accordingly.
"""

from astral import LocationInfo
from astral.sun import sun, dawn, dusk
from datetime import datetime, timedelta
import subprocess
import os
import sys
import time
from paho.mqtt import publish
import json
from dotenv import load_dotenv

# Load environment variables
load_dotenv("/home/indicatic-e1/Desktop/.env")

# Location configuration (Panama City)
CITY = LocationInfo("Panama City", "Panama", "America/Panama", 8.9833, -79.5167)

# MQTT broker config - from .env
BROKER_HOST = os.getenv("SERVER_IP")
BROKER_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_USER = os.getenv("SERVER_USER")  # 'user' or None
MQTT_PASS = os.getenv("SERVER_PASSWORD")  # 'pass' or None
TOPIC = "domo/command"
# Device IDs (your three ESP32)
DEVICE_IDS = ["qhy", "alpy", "nikon"]

# Topics
TOPIC_BROADCAST = "domo/command"
TOPIC_TEMPLATE = "domo/{device}/command"


def get_sun_times(date=None, sun_type="civil"):
    """Get sunrise and sunset times based on sun_type.

    Args:
        date: Date to calculate for. Defaults to today.
        sun_type: Type of calculation:
            - "civil": Civil twilight (sun at -6°)
            - "nautical": Nautical twilight (sun at -12°)
            - "astronomical": Astronomical twilight (sun at -18°)

    Returns:
        (rise_time, set_time) tuple where:
        - rise_time: Beginning of morning twilight (dome should CLOSE)
        - set_time: End of evening twilight (dome should OPEN)
    """
    if date is None:
        date = datetime.now().date()

    if sun_type == "civil":
        # Civil twilight: sun at -6° (default for dawn/dusk)
        morning = dawn(CITY.observer, date=date, tzinfo=CITY.timezone)
        evening = dusk(CITY.observer, date=date, tzinfo=CITY.timezone)
        return morning, evening
    elif sun_type == "nautical":
        # Nautical twilight: sun at -12°
        morning = dawn(CITY.observer, date=date, tzinfo=CITY.timezone, depression=12)
        evening = dusk(CITY.observer, date=date, tzinfo=CITY.timezone, depression=12)
        return morning, evening
    elif sun_type == "astronomical":
        # Astronomical twilight: sun at -18°
        morning = dawn(CITY.observer, date=date, tzinfo=CITY.timezone, depression=18)
        evening = dusk(CITY.observer, date=date, tzinfo=CITY.timezone, depression=18)
        return morning, evening
    else:
        raise ValueError(f"Unknown sun_type: {sun_type}")


def send_command_to_esp32(cmd):
    """Publish the command to the configured MQTT topic.

    Returns True if the publish appears successful, False on error.
    """
    payload = cmd
    auth = None
    if MQTT_USER and MQTT_PASS:
        auth = {"username": MQTT_USER, "password": MQTT_PASS}
    try:
        publish.single(
            TOPIC,
            payload=payload,
            hostname=BROKER_HOST,
            port=BROKER_PORT,
            auth=auth,
            keepalive=60,
        )
        print(
            f"MQTT command '{cmd}' published to {BROKER_HOST}:{BROKER_PORT} topic {TOPIC}"
        )
        return True
    except Exception as e:
        print(f"Error publishing to MQTT: {e}")
        return False


def send_command_to_esp32(cmd, device_id=None, broadcast=True):
    """Publish the command to the configured MQTT topic.

    - If device_id is provided, publish only to that device's topic.
    - If broadcast is True, also publish to the global broadcast topic.

    Returns True if all publications succeeded (best-effort), False if any failed.
    """
    auth = None
    if MQTT_USER and MQTT_PASS:
        auth = {"username": MQTT_USER, "password": MQTT_PASS}

    success = True
    try:
        # publish to specific device
        if device_id:
            topic = TOPIC_TEMPLATE.format(device=device_id)
            publish.single(
                topic,
                payload=cmd,
                hostname=BROKER_HOST,
                port=BROKER_PORT,
                auth=auth,
                qos=1,
                keepalive=60,
            )
            print(
                f"MQTT command '{cmd}' published to {BROKER_HOST}:{BROKER_PORT} topic {topic}"
            )
        else:
            # publish to all known device topics
            for did in DEVICE_IDS:
                topic = TOPIC_TEMPLATE.format(device=did)
                publish.single(
                    topic,
                    payload=cmd,
                    hostname=BROKER_HOST,
                    port=BROKER_PORT,
                    auth=auth,
                    qos=1,
                    keepalive=60,
                )
                print(
                    f"MQTT command '{cmd}' published to {BROKER_HOST}:{BROKER_PORT} topic {topic}"
                )

        # optional broadcast
        if broadcast:
            publish.single(
                TOPIC_BROADCAST,
                payload=cmd,
                hostname=BROKER_HOST,
                port=BROKER_PORT,
                auth=auth,
                qos=1,
                keepalive=60,
            )
            print(
                f"MQTT command '{cmd}' published to broadcast topic {TOPIC_BROADCAST}"
            )

    except Exception as e:
        print(f"Error publishing to MQTT: {e}")
        success = False

    return success


def schedule_next_event(sun_type="civil"):
    """Schedule the next event (sunrise or sunset) in cron.

    Args:
        sun_type: Type of calculation (civil, nautical, astronomical)
    """
    sunrise, sunset = get_sun_times(sun_type=sun_type)
    now = datetime.now().astimezone(sunrise.tzinfo)
    script_path = os.path.abspath(__file__)

    sun_type_names = {
        "civil": "Civil",
        "nautical": "Nautical",
        "astronomical": "Astronomical",
    }
    type_name = sun_type_names.get(sun_type, sun_type)

    print(f"\n{'=' * 50}")
    print(f"Sun Type: {type_name} Twilight")
    print(f"{'=' * 50}")
    print(f"Current time: {now.strftime('%H:%M:%S')}")
    print(f"Rise: {sunrise.strftime('%H:%M:%S')}")
    print(f"Set: {sunset.strftime('%H:%M:%S')}")

    # Determine the next event
    if now < sunrise:
        next_event = sunrise
        next_action = "close"
        print(f"Next event: CLOSE (night) at {sunrise.strftime('%H:%M:%S')}")
    elif now < sunset:
        next_event = sunset
        next_action = "open"
        print(f"Next event: OPEN (day) at {sunset.strftime('%H:%M:%S')}")
    else:
        # Sunset already passed, schedule for tomorrow's sunrise
        tomorrow_sunrise, _ = get_sun_times(
            date=(now + timedelta(days=1)).date(), sun_type=sun_type
        )
        next_event = tomorrow_sunrise
        next_action = "close"
        print(f"Next event: CLOSE tomorrow at {tomorrow_sunrise.strftime('%H:%M:%S')}")

    # Create cron entry
    cron_minute = next_event.minute
    cron_hour = next_event.hour
    cron_day = next_event.day
    cron_month = next_event.month

    # Read current crontab and remove previous entries for this script
    try:
        current_cron = subprocess.check_output(
            ["crontab", "-l"], stderr=subprocess.DEVNULL
        ).decode("utf-8")
        lines = [
            line
            for line in current_cron.split("\n")
            if script_path not in line and "# Domo control" not in line and line.strip()
        ]
    except subprocess.CalledProcessError:
        lines = []

    # Add new entry
    lines.append(
        f"{cron_minute} {cron_hour} {cron_day} {cron_month} * /usr/bin/python3 {script_path} {next_action} {sun_type} >> /var/log/domo_control.log 2>&1"
    )
    lines.append("")

    # Write crontab
    new_cron = "\n".join(lines)
    process = subprocess.Popen(["crontab", "-"], stdin=subprocess.PIPE)
    process.communicate(new_cron.encode("utf-8"))

    print(f"✓ Cron scheduled for {next_event.strftime('%Y-%m-%d %H:%M:%S')}")


def scheduled():
    """Execute scheduled action based on command line arguments.

    Usage:
        python3 sun_time_broker.py [action] [sun_type]
        - action: 'open' or 'close' (optional, auto-detects if not provided)
        - sun_type: 'civil', 'nautical', 'astronomical' (default: civil)
    """
    action = None
    sun_type = "civil"  # Default

    # Parse arguments
    if len(sys.argv) > 1:
        action = sys.argv[1].lower()
    if len(sys.argv) > 2:
        sun_type = sys.argv[2].lower()

    # Validate sun_type
    if sun_type not in ["civil", "nautical", "astronomical"]:
        print(
            f"ERROR: Invalid sun_type '{sun_type}'. Must be civil, nautical, or astronomical."
        )
        sys.exit(1)

    sunrise, sunset = get_sun_times(sun_type=sun_type)
    now = datetime.now().astimezone(sunrise.tzinfo)

    # If action is provided, use it; otherwise auto-detect
    if action and action in ["open", "close"]:
        print(f"Executing action: {action.upper()}")
        send_command_to_esp32(action)
    else:
        # Auto-detect based on current time
        if now < sunset and now >= sunrise:
            print("Daytime → Executing: CLOSE dome")
            send_command_to_esp32("close")
        else:
            print("Nighttime → Executing: OPEN dome")
            send_command_to_esp32("open")

    # Schedule the next event
    schedule_next_event(sun_type=sun_type)


def show_times_info(sun_type="civil"):
    """Display sun times for debugging/info."""
    twilight_start, twilight_end = get_sun_times(sun_type=sun_type)
    sun_type_names = {
        "civil": "Civil",
        "nautical": "Nautical",
        "astronomical": "Astronomical",
    }
    type_name = sun_type_names.get(sun_type, sun_type)

    print(f"\n{'=' * 50}")
    print(f"{type_name} Twilight Times for Panama City")
    print(f"{'=' * 50}")
    print(
        f"Morning twilight starts: {twilight_start.strftime('%H:%M:%S')} → CLOSE dome"
    )
    print(f"Evening twilight ends:   {twilight_end.strftime('%H:%M:%S')} → OPEN dome")
    print(f"{'=' * 50}\n")


def main():
    """Main entry point."""
    if len(sys.argv) > 1 and sys.argv[1] == "--info":
        sun_type = sys.argv[2] if len(sys.argv) > 2 else "civil"
        show_times_info(sun_type)
    else:
        scheduled()


if __name__ == "__main__":
    main()
