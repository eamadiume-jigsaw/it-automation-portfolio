#!/usr/bin/env python3
"""
Network device monitor with alerting and gated auto-remediation.
Pings devices from devices.yml, logs uptime history to SQLite,
sends a Teams webhook alert on failure, and optionally attempts
remediation on devices explicitly flagged as safe to touch.
"""

import yaml
import sqlite3
import subprocess
import requests
import datetime
import time
import sys

CONFIG_FILE = "devices.yml"
DB_FILE = "monitor_history.db"
TEAMS_WEBHOOK_URL = "YOUR_TEAMS_WEBHOOK_URL"
import os

WINRM_USERNAME = "Administrator"
WINRM_PASSWORD = os.environ.get("VM_ADMIN_PASSWORD")

if not WINRM_PASSWORD:
    print("[ERROR] VM_ADMIN_PASSWORD environment variable not set. Exiting.")
    sys.exit(1)
FAILURE_THRESHOLD = 3          # consecutive failures before alert/remediation
CHECK_INTERVAL_SECONDS = 60    # how often to run a full cycle

# In-memory failure streak tracker (resets on script restart)
failure_streaks = {}


def load_devices():
    with open(CONFIG_FILE, "r") as f:
        config = yaml.safe_load(f)
    return config["devices"]


def init_db():
    conn = sqlite3.connect(DB_FILE)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS checks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_name TEXT,
            ip TEXT,
            status TEXT,
            timestamp TEXT
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS remediation_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_name TEXT,
            action TEXT,
            result TEXT,
            timestamp TEXT
        )
    """)
    conn.commit()
    conn.close()


def log_check(device_name, ip, status):
    conn = sqlite3.connect(DB_FILE)
    conn.execute(
        "INSERT INTO checks (device_name, ip, status, timestamp) VALUES (?, ?, ?, ?)",
        (device_name, ip, status, datetime.datetime.now().isoformat())
    )
    conn.commit()
    conn.close()


def log_remediation(device_name, action, result):
    conn = sqlite3.connect(DB_FILE)
    conn.execute(
        "INSERT INTO remediation_log (device_name, action, result, timestamp) VALUES (?, ?, ?, ?)",
        (device_name, action, result, datetime.datetime.now().isoformat())
    )
    conn.commit()
    conn.close()


def ping_device(ip):
    """Returns True if the device responds to a single ping, False otherwise."""
    result = subprocess.run(
        ["ping", "-c", "1", "-W", "2", ip],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )
    return result.returncode == 0


def send_teams_alert(message):
    if TEAMS_WEBHOOK_URL == "YOUR_TEAMS_WEBHOOK_URL":
        print(f"[ALERT - webhook not configured] {message}")
        return
    payload = {"text": message}
    try:
        requests.post(TEAMS_WEBHOOK_URL, json=payload, timeout=5)
    except requests.RequestException as e:
        print(f"[WARNING] Failed to send Teams alert: {e}")


def attempt_remediation(device):
    import winrm

    service_name = device.get("remediation_service")
    if not service_name:
        result = "skipped - no remediation_service configured"
        print(f"[REMEDIATION] {device['name']}: {result}")
        log_remediation(device["name"], "none", result)
        return

    action = f"Restart-Service '{service_name}' on {device['name']}"
    print(f"[REMEDIATION] Attempting: {action}")

    try:
        session = winrm.Session(
            device["ip"],
            auth=(WINRM_USERNAME, WINRM_PASSWORD),
            transport="basic",
            server_cert_validation="ignore"
        )
        ps_command = f"Restart-Service -Name '{service_name}' -Force; Get-Service -Name '{service_name}' | Select-Object -ExpandProperty Status"
        response = session.run_ps(ps_command)
        output = response.std_out.decode().strip()
        result = f"success - service status now: {output}"
        print(f"[REMEDIATION] {result}")
    except Exception as e:
        result = f"failed - {str(e)}"
        print(f"[REMEDIATION] {result}")

    log_remediation(device["name"], action, result)


def check_device(device):
    name = device["name"]
    ip = device["ip"]
    is_up = ping_device(ip)
    status = "up" if is_up else "down"
    log_check(name, ip, status)

    if is_up:
        failure_streaks[name] = 0
        print(f"[OK] {name} ({ip}) is up")
    else:
        failure_streaks[name] = failure_streaks.get(name, 0) + 1
        print(f"[FAIL] {name} ({ip}) is down - streak: {failure_streaks[name]}")

        if failure_streaks[name] == FAILURE_THRESHOLD:
            message = f"🔴 ALERT: {name} ({ip}) has failed {FAILURE_THRESHOLD} consecutive checks."
            send_teams_alert(message)

            if device.get("remediation_enabled", False):
                attempt_remediation(device)


def main():
    init_db()
    devices = load_devices()
    print(f"Monitoring {len(devices)} device(s). Checking every {CHECK_INTERVAL_SECONDS}s. Ctrl+C to stop.")

    try:
        while True:
            for device in devices:
                check_device(device)
            time.sleep(CHECK_INTERVAL_SECONDS)
    except KeyboardInterrupt:
        print("\nStopping monitor.")
        sys.exit(0)


if __name__ == "__main__":
    main()
