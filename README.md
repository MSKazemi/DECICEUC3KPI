# DECICE Use Case 3 — KPI Measurement & Benchmarking

Key Performance Indicator (KPI) measurement, benchmarking, and analysis tooling for **Use Case 3 (UC3)** of the [DECICE](https://www.decice.eu/) project — an EU Horizon Europe research and innovation action on the **cloud–edge–HPC compute continuum**.

This repository collects and analyzes end-to-end performance metrics from a distributed UC3 workload running on **Kubernetes**, where a robotics/UAV image pipeline (ROS 2, PX4 SITL, and YOLO object detection) is spread across cloud, edge, and simulation nodes.

- **DECICEUC3KPI is** an open-source collection of Python scripts and Kubernetes manifests for measuring cloud–edge performance KPIs.
- **It is for** researchers and engineers evaluating the DECICE framework and, more broadly, anyone benchmarking latency and energy on a Kubernetes cloud–edge testbed.
- **It helps you** collect image-processing and YOLO inference latency, estimate edge power/energy consumption, and measure Kubernetes node-failure recovery time.
- **Use it when** you need reproducible KPI numbers (mean, min, max, std, pooled/weighted aggregates) for a DECICE UC3-style deployment.
- **It is not** a general-purpose monitoring platform or a scheduler — it is an experiment-specific measurement and analysis toolkit.

## Role in DECICE UC3

DECICE (Device-Edge-Cloud Intelligent Collaboration framEwork) develops an AI-based, open, and portable framework for adaptive workload placement across the cloud–edge–HPC continuum. **Use Case 3** exercises this continuum with a distributed robotics/UAV workload:

- **PX4 SITL** software-in-the-loop drone simulation (`gz_x500`) and `MicroXRCEAgent` bridging.
- **ROS 2** nodes from a `decice_sat` package: `metrics_collector`, `risk_image_publisher`, `standard_image_publisher`, `image_processor`, `goal_sender`, `yolo_workload` (nano model on the edge), and `offboard_control`.
- Workload steps distributed across labelled Kubernetes nodes (simulation, cloud, and edge, including Raspberry Pi 4 class edge devices) in the `uc3` namespace.

This repository is the **measurement and evaluation layer** for that use case: it ingests per-session metric CSV/JSON produced by the workload and the cluster's Prometheus, then computes the KPIs used to assess UC3 performance.

## KPIs measured

| KPI | What it captures | Produced by |
| --- | --- | --- |
| **Image-processing latency (ms)** | Per-frame processing time (mean/min/max/std, count) | `aggregate.py`, `*_summary.json` |
| **YOLO inference latency (ms)** | Object-detection inference time on the edge | `aggregate.py`, `*_summary.json` |
| **Power / energy consumption (W)** | CPU-based power estimate for edge nodes (Raspberry Pi 4 model: `1.6 W`/core + idle) | `power_estimation.py`, `power_estimation2.py`, `power_estimation3.py` |
| **Node-failure recovery time** | Time from simulated node failure to pod *Scheduled → Running → Ready* | `node_failure/` |

Aggregation uses **weighted means** across sessions and a **pooled standard deviation** so per-session summaries combine into a single overall KPI (`aggregate.py` → `overall_summary_ai.json`).

## Repository contents

- `aggregate.py` — merge per-session `*_summary.json` files into weighted/pooled overall KPIs.
- `power_estimation*.py` — estimate average power/energy from CPU-core time series (Prometheus-exported CSV).
- `plot.py` — plot CPU-core usage over time (matplotlib).
- `failure.py` — quick mean/variance helper for failure-timing samples.
- `data_collection_prometheus.ipynb` — query a cluster Prometheus (`/api/v1/query_range`) and export metrics to CSV.
- `decice_cmds` — operational command notes for bringing up the UC3 ROS 2 / PX4 nodes on the cluster.
- `*.yaml` (`uc3-kpi.yaml`, `uc3_deployment.yaml`, `uc3-v1*.yaml`, `uc3-kpi-e4*.yaml`) — Kubernetes manifests for the `uc3` namespace deployments.
- `node_failure/` — node-failure resiliency experiment (kind config, phase scripts, `run_experiment.sh`, and a phase-definition `readme.md`).
- `uc3_results/`, `new_uc3_kpis/`, `csv_files/`, `images/` — collected measurements, summaries, and screenshots.

## Requirements

- Python 3.12+
- `matplotlib` (plotting), `requests` (Prometheus queries); the KPI/power scripts otherwise use the standard library (`csv`, `json`, `statistics`, `datetime`).
- For the experiments themselves: a Kubernetes cluster (a `kind` config is provided for the node-failure test), `kubectl`, and a reachable Prometheus endpoint.

```bash
pip install matplotlib requests
```

## Usage

Aggregate per-session KPI summaries into overall metrics:

```bash
python aggregate.py        # writes overall_summary_ai.json
```

Estimate edge power/energy from a CPU-cores CSV:

```bash
python power_estimation3.py
```

Plot CPU usage over time:

```bash
python plot.py
```

Run the Kubernetes node-failure recovery experiment:

```bash
cd node_failure
./run_experiment.sh
```

> **Note:** several scripts contain hardcoded absolute paths, Prometheus URLs/IPs, and experiment time intervals from the original test runs. Edit these to match your own folders, cluster endpoint, and measurement windows before running.

## Limitations / when not to use

- This is **experiment-specific research tooling**, not a packaged library — expect to edit paths, IPs, and time windows in the scripts.
- Power figures are **model-based estimates** (CPU-core count × per-core watts + idle), tuned for Raspberry Pi 4 class edge nodes — they are not physical power-meter measurements.
- The Kubernetes manifests reference project-specific container images and node labels from the DECICE UC3 testbed.

## Funding acknowledgement

This work is part of the **DECICE** project (Device-Edge-Cloud Intelligent Collaboration framEwork), funded by the **European Union's Horizon Europe** research and innovation programme under **grant agreement No 101092582**. See [decice.eu](https://www.decice.eu/) and the [CORDIS fact sheet](https://cordis.europa.eu/project/id/101092582).

## Author

Mohsen Seyedkazemi Ardebili — University of Bologna (DECICE UC3). This is a collaborative EU-project repository.

## License

No license is set. As an institutional/collaborative EU-project (DECICE) repository, licensing is deferred to the project consortium.

<!-- legal-notice: start -->
### Legal notice and responsible use

The materials in this repository are made available without warranties to the extent permitted by applicable law. **Please read the [Disclaimer and Responsible-Use Notice](DISCLAIMER.md)** before relying on or deploying them. This notice does not change any existing software license or limit rights that cannot legally be waived.
<!-- legal-notice: end -->

<!-- risk-guidance: start -->
### Operational safety and limitations

Before connecting accounts, running automation, relying on consequential outputs, or using production systems, review [project-specific safety risks and pre-deployment checks](SAFETY.md). The checklist describes precautions to **verify**, not a certification that the software currently enforces every safeguard.
<!-- risk-guidance: end -->

<!-- licensing-status: start -->
### Licensing and reuse status

**No repository-root license has yet been confirmed for this project.** Read [Rights and Licensing Status](LICENSING_STATUS.md) before copying, redistributing, or adapting code or content. A public repository and its disclaimer do not by themselves grant new reuse permissions. Existing valid third-party rights and licenses remain in effect.
<!-- licensing-status: end -->
