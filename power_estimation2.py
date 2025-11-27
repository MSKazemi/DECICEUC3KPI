import csv
from datetime import datetime
import json
from statistics import mean, stdev

# CSV_FILE = "csv_files/cpu_last_5_hours_highres.csv"
CSV_FILE = "csv_files/edge_cpu_last_5_hours_ai.csv"

CPU_POWER_WATT = 1.6  # per core for Raspberry Pi 4
IDLE_WATT = 3.0       # example, tune from measurements

# Define experiment intervals as (start, end) in ISO format
# OLD
# intervals = [
#     ("2025-11-17T14:37:38", "2025-11-17T14:39:23"),
#     ("2025-11-17T14:39:23", "2025-11-17T14:41:08"),
#     ("2025-11-17T14:41:08", "2025-11-17T14:43:08"),
#     ("2025-11-17T14:43:08", "2025-11-17T14:45:08"),
#     ("2025-11-17T14:55:53", "2025-11-17T14:57:23"),
#     ("2025-11-17T14:58:23", "2025-11-17T15:00:08"),
#     ("2025-11-17T15:00:53", "2025-11-17T15:02:23"),
# ]

intervals = [
    ("2025-11-27T12:49:17", "2025-11-27T12:51:02"),
    ("2025-11-27T12:52:17", "2025-11-27T12:54:32"),
    ("2025-11-27T13:03:47", "2025-11-27T13:05:47"),
    ("2025-11-27T13:05:47", "2025-11-27T13:07:32"),
    ("2025-11-27T13:07:47", "2025-11-27T13:09:32"),
    ("2025-11-27T13:09:32", "2025-11-27T13:11:17"),
    ("2025-11-27T13:14:17", "2025-11-27T13:16:32"),
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

def get_interval_mean_power(start_dt, end_dt):
    window = [s for s in samples if start_dt <= s["dt"] <= end_dt]
    power_samples = []
    for i in range(1, len(window)):
        avg_cpu = (window[i]["cpu_cores"] + window[i-1]["cpu_cores"]) / 2
        power = avg_cpu * CPU_POWER_WATT + IDLE_WATT
        power_samples.append(power)
    return mean(power_samples) if power_samples else None

interval_means = []
for start_str, end_str in intervals:
    start_dt = datetime.fromisoformat(start_str)
    end_dt = datetime.fromisoformat(end_str)
    avg_power = get_interval_mean_power(start_dt, end_dt)
    if avg_power is not None:
        interval_means.append(avg_power)

summary = {
    "power_consumption": {
        "count": len(intervals),
        "mean": mean(interval_means) if interval_means else None,
        "min": min(interval_means) if interval_means else None,
        "max": max(interval_means) if interval_means else None,
        "std": stdev(interval_means) if len(interval_means) > 1 else 0.0
    }
}

with open("power_summary_off.json", "w") as f:
    json.dump(summary, f, indent=2)

print(json.dumps(summary, indent=2))