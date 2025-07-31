#!/bin/bash

set -e
set -o pipefail

DEPLOYMENT_NAME="test-app"
APP_LABEL="app=test-app"
NAMESPACE="default"
NODE1="decice-worker"
NODE2="decice-worker2"
RESULT_FILE="recreation_times.txt"

# Check dependencies
command -v jq >/dev/null || { echo "❌ jq is required but not installed."; exit 1; }

# Prepare output file
echo "📄 Recreation Times Log - $(date)" > "$RESULT_FILE"
echo "----------------------------------" >> "$RESULT_FILE"
echo "iteration,timestamp,duration_milliseconds,node" >> "$RESULT_FILE"

# Cleanup existing deployment
kubectl delete deployment "$DEPLOYMENT_NAME" --ignore-not-found >/dev/null 2>&1 || true


# Pod ready wait helper
wait_for_single_ready_pod() {
  local timeout=120
  local start_time=$(date +%s)

  while true; do
    pods_json=$(kubectl get pods -l "$APP_LABEL" -o json)
    ready_pods=$(echo "$pods_json" | jq '[.items[] | select(.status.containerStatuses[0].ready == true)] | length')
    total_pods=$(echo "$pods_json" | jq '.items | length')

    if [[ "$ready_pods" == "1" && "$total_pods" == "1" ]]; then
      return 0
    fi

    current_time=$(date +%s)
    if (( current_time - start_time > timeout )); then
      echo "❌ Timeout waiting for a single Ready pod"
      kubectl get pods -l "$APP_LABEL" -o wide
      kubectl describe pod -l "$APP_LABEL"
      return 1
    fi
    sleep 2
  done
}

# Create deployment
#  add command to pod to sleep 1000 seconds to ensure it stays up long enough for testing
echo "🚀 Creating deployment $DEPLOYMENT_NAME"
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
        - name: uc3step2
          image: sebastianomengozzi/uc3step2:latest
          command: ["sleep", "1000"]
EOF

# Wait for initial pod to be ready
if ! wait_for_single_ready_pod; then
  echo "❌ Initial deployment failed" >> "$RESULT_FILE"
  exit 1
fi

# Pin to NODE1
kubectl patch deployment "$DEPLOYMENT_NAME" \
  -p "{\"spec\": {\"template\": {\"spec\": {\"nodeSelector\": {\"kubernetes.io/hostname\": \"$NODE1\"}}}}}"

kubectl rollout restart deployment "$DEPLOYMENT_NAME" >/dev/null

if ! wait_for_single_ready_pod; then
  echo "❌ Initial pod relocation to $NODE1 failed" >> "$RESULT_FILE"
  exit 1
fi

# Main test loop
for i in $(seq 1 100); do
  echo "🔁 Iteration $i"
  timestamp=$(date +'%Y-%m-%d %H:%M:%S')

  # Remove nodeSelector and rollout restart
  kubectl patch deployment "$DEPLOYMENT_NAME" \
    --type='json' \
    -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector"}]' >/dev/null
  kubectl rollout restart deployment "$DEPLOYMENT_NAME" >/dev/null

  # Start timer
  start=$(date +%s%3N)

  # Drain NODE1 to force reschedule
  kubectl drain "$NODE1" --ignore-daemonsets --delete-emptydir-data --force --grace-period=0 --timeout=60s >/dev/null 2>&1 || true

  # Wait for pod to be ready
  if ! wait_for_single_ready_pod; then
    echo "❌ Iteration $i FAILED (timeout)" >> "$RESULT_FILE"
    exit 1
  fi

  end=$(date +%s%3N)
  duration=$((end - start))

  # Log pod node
  pod_name=$(kubectl get pod -l "$APP_LABEL" -o jsonpath='{.items[0].metadata.name}')
  pod_node=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.nodeName}')

  echo "✅ Iteration $i complete (took $duration milliseconds on $pod_node)"
  echo "$i,$timestamp,$duration,$pod_node" >> "$RESULT_FILE"

  # Re-pin to NODE1
  kubectl patch deployment "$DEPLOYMENT_NAME" \
    -p "{\"spec\": {\"template\": {\"spec\": {\"nodeSelector\": {\"kubernetes.io/hostname\": \"$NODE1\"}}}}}" >/dev/null
  kubectl rollout restart deployment "$DEPLOYMENT_NAME" >/dev/null

  # Cleanup and prepare next iteration
  kubectl delete pod -l "$APP_LABEL" --ignore-not-found >/dev/null
  kubectl uncordon "$NODE1" 

  if ! wait_for_single_ready_pod; then
    echo "❌ Iteration $i (re-pin to $NODE1) failed" >> "$RESULT_FILE"
    exit 1
  fi

  sleep 2
done

echo "✅ All 100 iterations complete."
echo "📊 Results saved in $RESULT_FILE"
