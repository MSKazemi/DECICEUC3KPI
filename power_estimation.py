import csv
from datetime import datetime

CSV_FILE = "csv_files/cpu_last_5_hours_highres.csv"
CPU_POWER_WATT = 1.6  # per core for Raspberry Pi 4
IDLE_WATT = 3.0          # example, tune from measurements

# Define experiment intervals as (start, end) in ISO format
intervals = [
    ("2025-11-17T14:37:38", "2025-11-17T14:39:23"),
    ("2025-11-17T14:39:23", "2025-11-17T14:41:08"),
    ("2025-11-17T14:41:08", "2025-11-17T14:43:08"),
    ("2025-11-17T14:43:08", "2025-11-17T14:45:08"),
    ("2025-11-17T14:55:53", "2025-11-17T14:57:23"),
    ("2025-11-17T14:58:23", "2025-11-17T15:00:08"),
    ("2025-11-17T15:00:53", "2025-11-17T15:02:23"),
]

# Load CSV data
samples = []
with open(CSV_FILE) as f:
    reader = csv.DictReader(f)
    for row in reader:
        samples.append({
            "timestamp": int(row["timestamp"]),
            "datetime_utc": row["datetime_utc"],
            "cpu_cores": float(row["cpu_cores"]),
            "dt": datetime.fromisoformat(row["datetime_utc"])
        })

def average_power(start_dt, end_dt):
    window = [s for s in samples if start_dt <= s["dt"] <= end_dt]
    if len(window) < 2:
        return 0
    total_power = 0
    total_time = 0
    for i in range(1, len(window)):
        dt_sec = (window[i]["dt"] - window[i-1]["dt"]).total_seconds()
        avg_cpu = (window[i]["cpu_cores"] + window[i-1]["cpu_cores"]) / 2
        power = avg_cpu * CPU_POWER_WATT + IDLE_WATT
        total_energy += power * dt_sec
        total_time += dt_sec
    return total_energy / total_time if total_time > 0 else 0

powers = []
print("Power estimation for specified intervals:")
for idx, (start_str, end_str) in enumerate(intervals, 1):
    start_dt = datetime.fromisoformat(start_str)
    end_dt = datetime.fromisoformat(end_str)
    avg_power = average_power(start_dt, end_dt)
    powers.append(avg_power)
    print(f"Experiment {idx}: {start_str} to {end_str} -> {avg_power:.4f} W")

if powers:
    print("Mean power consumption (Watts):", sum(powers)/len(powers))
else:
    print("No valid intervals found.")