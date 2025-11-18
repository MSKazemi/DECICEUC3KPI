#!/bin/bash

set -e
set -o pipefail


DEPLOYMENT_NAME="test-app"
APP_LABEL="app=test-app"
NAMESPACE="default"
NODE_A="acnode06.e4red"
NODE_B="acnode10.e4red"
RESULT_FILE="node_failure_experiment.csv"

# Check dependencies
command -v jq >/dev/null || { echo "❌ jq is required but not installed."; exit 1; }

echo "phase,timestamp,note" > "$RESULT_FILE"

# Step 0: Deploy the app
kubectl delete deployment "$DEPLOYMENT_NAME" --ignore-not-found >/dev/null 2>&1 || true
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

# Wait for pod to be ready
echo "Waiting for initial pod to be ready..."
until kubectl get pods -l "$APP_LABEL" -o json | jq -e '[.items[] | select(.status.containerStatuses[0].ready == true)] | length == 1' >/dev/null; do
  sleep 10
done

# Identify the node where the pod is running
pod_name=$(kubectl get pod -l "$APP_LABEL" -o jsonpath='{.items[0].metadata.name}')
initial_node=$(kubectl get pod "$pod_name" -o jsonpath='{.spec.nodeName}')

echo "✅ Pod $pod_name is ready on node $initial_node"
echo "INFO,$(date +%s%3N),Pod initially scheduled to $initial_node" >> "$RESULT_FILE"



# Step 1: Simulate node failure (Kind)
echo "🚨 Simulating failure of node $initial_node"
docker stop $initial_node
echo "2a,$(date +%s%3N),Node $initial_node stopped (simulate failure)" >> "$RESULT_FILE"






# Step 1: Simulate node failure (E4)
echo "🚨 Simulating failure of node $initial_node"

# Define SSH user and SSH key if needed
SSH_USER="ubuntu"           # replace with your SSH username
SSH_KEY="~/.ssh/id_rsa"     # optional: specify the SSH key if needed

# Stop kubelet on the target node
ssh -i "$SSH_KEY" "$SSH_USER@$initial_node" "/usr/bin/systemctl stop kubelet && /usr/bin/systemctl stop containerd"

echo "2a,$(date +%s%3N),Node $initial_node kubelet stopped (simulate failure)" >> "$RESULT_FILE"





# Step 2: Watch for new pod scheduled (ignore eviction of old one)
echo "⏳ Watching for new pod scheduling..."
while true; do
  new_pod=$(kubectl get pods -l "$APP_LABEL" -o json | jq -r \
    --arg old "$pod_name" '.items[] | select(.metadata.name != $old and .status.phase == "Pending") | .metadata.name' | head -n1)
  if [[ -n "$new_pod" ]]; then
    echo "3a,$(date +%s%3N),New pod $new_pod scheduled" >> "$RESULT_FILE"
    break
  fi
  sleep 1
done

# Step 3b: Pod enters Running phase
while true; do
  phase=$(kubectl get pod "$new_pod" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [[ "$phase" == "Running" ]]; then
    echo "3b,$(date +%s%3N),New pod entered Running phase" >> "$RESULT_FILE"
    break
  fi
  sleep 1
done

# Step 3c: Pod Ready condition
while true; do
  ready=$(kubectl get pod "$new_pod" -o json | jq '[.status.containerStatuses[] | select(.ready == true)] | length')
  if [[ "$ready" -ge 1 ]]; then
    echo "3c,$(date +%s%3N),New pod became Ready" >> "$RESULT_FILE"
    break
  fi
  sleep 1
done
