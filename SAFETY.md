# Safety, limitations and pre-deployment checks — DECICEUC3KPI

**Scope:** Research scripts and Kubernetes manifests for cloud-edge HPC/ROS 2/UAV benchmarking and node-failure experiments.  
**Issued:** 2026-10-17  
**Status:** Risk guidance only. No claim is made that any checklist item is already implemented, tested, legally approved or certified.

This document supplements [DISCLAIMER.md](DISCLAIMER.md) and the existing copyright/license terms without changing either. It does not prevent claims or waive mandatory legal duties.

## Risks to assess

- Failure experiments and test scripts may deliberately interrupt Kubernetes nodes or workloads.
- Hardcoded paths, URLs, IPs, node labels and research configuration may target unintended resources.
- Simulation performance data and model-based power estimates are not verified physical measurements.

## Checks before live use

- [ ] Run failure tests only in an authorized isolated environment, never shared/production infrastructure.
- [ ] Review every destructive or privileged command and hardcoded endpoint before running scripts.
- [ ] Record test configuration, boundaries, consent, backup/rollback and source of measured versus estimated values.
- [ ] Keep model-based KPI conclusions separate from live safety and infrastructure control decisions.

## User and maintainer responsibilities

Begin in an isolated, authorized test environment; apply least privilege, backups, monitoring and an independent review of any high-impact outputs or actions. Where a project depends on third-party providers or real equipment, comply with vendor terms and safety instructions. Report suspected security flaws privately. Record actual test evidence, versions and unresolved risks rather than inferring that documentation is proof of implementation.

**Mandatory rights preserved:** Liability, product-safety, privacy, security and consumer obligations cannot be eliminated by this notice where applicable law forbids exclusion.
