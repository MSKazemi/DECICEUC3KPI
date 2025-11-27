import csv
from datetime import datetime
import json
from statistics import mean, stdev

CPU_POWER_WATT = 1.6  # per core for Raspberry Pi 4
IDLE_WATT = 3.0       # idle power, to be added at the end

intervals_highres = [
    ("2025-11-17T14:37:38", "2025-11-17T14:39:23"),
    ("2025-11-17T14:39:23", "2025-11-17T14:41:08"),
    ("2025-11-17T14:41:08", "2025-11-17T14:43:08"),
    ("2025-11-17T14:43:08", "2025-11-17T14:45:08"),
    ("2025-11-17T14:55:53", "2025-11-17T14:57:23"),
    ("2025-11-17T14:58:23", "2025-11-17T15:00:08"),
    ("2025-11-17T15:00:53", "2025-11-17T15:02:23"),
]
intervals_edge = [
    ("2025-11-27T12:49:17", "2025-11-27T12:51:02"),
    ("2025-11-27T12:52:17", "2025-11-27T12:54:32"),
    ("2025-11-27T13:03:47", "2025-11-27T13:05:47"),
    ("2025-11-27T13:05:47", "2025-11-27T13:07:32"),
    ("2025-11-27T13:07:47", "2025-11-27T13:09:32"),
    ("2025-11-27T13:09:32", "2025-11-27T13:11:17"),
    ("2025-11-27T13:14:17", "2025-11-27T13:16:32"),
]

def load_samples(csv_file):
    samples = []
    with open(csv_file) as f:
        reader = csv.DictReader(f)
        for row in reader:
            samples.append({
                "timestamp": int(row["timestamp"]),
                "datetime_utc": row["datetime_utc"],
                "cpu_cores": float(row["cpu_cores"]),
                "dt": datetime.fromisoformat(row["datetime_utc"])
            })
    return samples

def interval_energy_and_time(samples, start_dt, end_dt):
    window = [s for s in samples if start_dt <= s["dt"] <= end_dt]
    energy = 0.0
    total_time = 0.0
    for i in range(1, len(window)):
        dt_sec = (window[i]["dt"] - window[i-1]["dt"]).total_seconds()
        avg_cpu = (window[i]["cpu_cores"] + window[i-1]["cpu_cores"]) / 2
        power = avg_cpu * CPU_POWER_WATT
        energy += power * dt_sec
        total_time += dt_sec
    return energy, total_time

samples_highres = load_samples("csv_files/cpu_last_5_hours_highres.csv")
samples_edge = load_samples("csv_files/edge_cpu_last_5_hours_ai.csv")

interval_avg_powers = []

for (start1, end1), (start2, end2) in zip(intervals_highres, intervals_edge):
    s1 = datetime.fromisoformat(start1)
    e1 = datetime.fromisoformat(end1)
    s2 = datetime.fromisoformat(start2)
    e2 = datetime.fromisoformat(end2)
    energy1, time1 = interval_energy_and_time(samples_highres, s1, e1)
    energy2, time2 = interval_energy_and_time(samples_edge, s2, e2)
    total_energy = energy1 + energy2
    total_time = time1  # assume both intervals are the same length
    # Add idle power for this interval
    total_energy += IDLE_WATT * total_time
    avg_power = total_energy / total_time if total_time > 0 else None
    if avg_power is not None:
        interval_avg_powers.append(avg_power)

summary = {
    "power_consumption": {
        "count": len(interval_avg_powers),
        "mean": mean(interval_avg_powers) if interval_avg_powers else None,
        "min": min(interval_avg_powers) if interval_avg_powers else None,
        "max": max(interval_avg_powers) if interval_avg_powers else None,
        "std": stdev(interval_avg_powers) if len(interval_avg_powers) > 1 else 0.0
    }
}

with open("power_summary_sum_intervals.json", "w") as f:
    json.dump(summary, f, indent=2)

print(json.dumps(summary, indent=2))