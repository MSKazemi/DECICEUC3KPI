import json
import os
from statistics import mean

# folder = "/home/smengozzi/work/git/DECICEUC3KPI/uc3_results"
folder = "/home/smengozzi/work/git/DECICEUC3KPI/new_uc3_kpis"   

summary_files = [f for f in os.listdir(folder) if f.endswith("_summary.json")]

def collect_stats(section):
    means, stds, counts, maxs, mins = [], [], [], [], []
    for fname in summary_files:
        with open(os.path.join(folder, fname)) as f:
            data = json.load(f)
            if section in data:
                s = data[section]
                if "mean_ms" in s: means.append(s["mean_ms"])
                if "std_ms" in s: stds.append(s["std_ms"])
                if "count" in s: counts.append(s["count"])
                if "max_ms" in s: maxs.append(s["max_ms"])
                if "min_ms" in s: mins.append(s["min_ms"])
    return means, stds, counts, maxs, mins

def pooled_std(means, stds, counts):
    if not means or not stds or not counts or sum(counts) <= 1:
        return None
    # Weighted mean
    mu_pooled = sum(m * n for m, n in zip(means, counts)) / sum(counts)
    # Numerator: sum of within-group and between-group variances
    numerator = sum((n - 1) * (s ** 2) for s, n in zip(stds, counts))
    numerator += sum(n * ((m - mu_pooled) ** 2) for m, n in zip(means, counts))
    denominator = sum(counts) - 1
    return (numerator / denominator) ** 0.5 if denominator > 0 else None

ip_means, ip_stds, ip_counts, ip_maxs, ip_mins = collect_stats("image_processing")
yolo_means, yolo_stds, yolo_counts, yolo_maxs, yolo_mins = collect_stats("yolo")

def weighted_mean(means, counts):
    return sum(m * n for m, n in zip(means, counts)) / sum(counts) if means and counts and sum(counts) > 0 else None

overall_summary = {
    "image_processing": {
        "total_count": sum(ip_counts),
        "overall_max": max(ip_maxs) if ip_maxs else None,
        "overall_min": min(ip_mins) if ip_mins else None,
        "weighted_avg": weighted_mean(ip_means, ip_counts),
        "overall_std": pooled_std(ip_means, ip_stds, ip_counts)
    },
    "yolo": {
        "total_count": sum(yolo_counts),
        "overall_max": max(yolo_maxs) if yolo_maxs else None,
        "overall_min": min(yolo_mins) if yolo_mins else None,
        "weighted_avg": weighted_mean(yolo_means, yolo_counts),
        "overall_std": pooled_std(yolo_means, yolo_stds, yolo_counts)
    }
}

with open(os.path.join(folder, "overall_summary_ai.json"), "w") as f:
    json.dump(overall_summary, f, indent=2)

print(json.dumps(overall_summary, indent=2))