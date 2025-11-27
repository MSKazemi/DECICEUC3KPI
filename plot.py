import csv
from datetime import datetime
import matplotlib.pyplot as plt

CSV_FILE = "csv_files/edge_cpu_last_5_hours_ai.csv"

timestamps = []
cpu_cores = []

with open(CSV_FILE) as f:
    reader = csv.DictReader(f)
    for row in reader:
        dt = datetime.fromisoformat(row["datetime_utc"])
        cpu = float(row["cpu_cores"])
        timestamps.append(dt)
        cpu_cores.append(cpu)

plt.figure(figsize=(12, 5))
plt.plot(timestamps, cpu_cores, marker='.', linestyle='-', color='b')
plt.xlabel("Time (UTC)")
plt.ylabel("CPU cores used")
plt.title("CPU usage vs Time")
plt.grid(True)
plt.tight_layout()

# Annotate only non-zero points with their x coordinate (time), bigger font
for x, y in zip(timestamps, cpu_cores):
    if y != 0:
        plt.annotate(f"{x.strftime('%H:%M:%S')}", (x, y),
                     textcoords="offset points", xytext=(0,8), ha='center', fontsize=14, rotation=90, fontweight='bold')

plt.show()