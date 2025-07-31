#!/bin/bash
kubectl delete deployment test-app --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pod -l app=test-app --grace-period=0 --force >/dev/null 2>&1 || true
docker unpause decice-worker >/dev/null
docker unpause decice-worker2 >/dev/null
docker start decice-worker >/dev/null
docker start decice-worker2 >/dev/null
kubectl uncordon decice-worker >/dev/null
kubectl uncordon decice-worker2 >/dev/null

