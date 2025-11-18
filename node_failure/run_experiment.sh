#!/bin/bash
set -euo pipefail

# ========= CONFIG =========
DEPLOYMENT_NAME="test-app"
APP_LABEL="app=test-app"
NAMESPACE="default"

NODE_A="acnode10.e4red"
NODE_B="acnode11.e4red"

MODE="${MODE:-ssh}"

# Default SSH settings (can be overridden per-node below)
DEFAULT_SSH_USER="${SSH_USER:-mseyedkazemi}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=accept-new -i ${SSH_KEY}"

# Optional: per-node SSH user map (uncomment/adapt if nodes use different users)
declare -A NODE_USER
NODE_USER["${NODE_A}"]="${DEFAULT_SSH_USER}"
NODE_USER["${NODE_B}"]="${DEFAULT_SSH_USER}"

RESULT_FILE="node_failure_experiment.csv"
# ==========================

command -v jq >/dev/null || { echo "❌ jq is required but not installed."; exit 1; }

echo "phase,timestamp,note" > "$RESULT_FILE"

# ---- Helper: log line to CSV ----
log_csv () { echo "$1,$(date +%s%3N),$2" | tee -a "$RESULT_FILE"; }

get_user_for_node () {
  local node="$1"
  if [[ -n "${NODE_USER[$node]:-}" ]]; then
    echo "${NODE_USER[$node]}"
  else
    echo "${DEFAULT_SSH_USER}"
  fi
}




# ---- (Re)deploy pinned to the two nodes ----
echo "🚀 (Re)Deploying $DEPLOYMENT_NAME constrained to $NODE_A / $NODE_B"
kubectl -n "$NAMESPACE" delete deployment "$DEPLOYMENT_NAME" --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NAMESPACE" apply -f - <<EOF
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
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/hostname
                operator: In
                values:
                - $NODE_A
                - $NODE_B
      containers:
      - name: uc3step2
        image: sebastianomengozzi/uc3step2:latest
        command: ["sleep", "1000"]
EOF

echo "⏳ Waiting for initial pod to be Ready on one of the two nodes..."
until kubectl -n "$NAMESPACE" get pods -l "$APP_LABEL" -o json \
  | jq -e '[.items[] | select(.status.containerStatuses[0].ready == true)] | length == 1' >/dev/null; do
  sleep 2
done

POD_OLD=$(kubectl -n "$NAMESPACE" get pod -l "$APP_LABEL" -o jsonpath='{.items[0].metadata.name}')
NODE_OLD=$(kubectl -n "$NAMESPACE" get pod "$POD_OLD" -o jsonpath='{.spec.nodeName}')
log_csv "INFO" "Pod initially scheduled to $NODE_OLD"



# ---- Simulate node failure ----
echo "🚨 Simulating failure of node $NODE_OLD (MODE=$MODE)"
if [[ "$MODE" == "kind" ]]; then
  KCONT=$(docker ps --format '{{.Names}}' | grep -w "kind-${NODE_OLD}" || true)
  [[ -z "$KCONT" ]] && { echo "❌ Could not find kind container for node $NODE_OLD" >&2; exit 1; }
  docker stop "$KCONT" >/dev/null
  log_csv "2a" "Kind container for $NODE_OLD stopped"
else
  # If target is local node, run commands locally; else SSH
  if [[ "$(hostname -f 2>/dev/null || hostname)" == "$NODE_OLD" ]]; then
    if sudo -n systemctl stop kubelet && sudo -n systemctl stop containerd; then
      log_csv "2a" "kubelet/containerd stopped locally on $NODE_OLD"
    else
      echo "❌ Local sudo failed on $NODE_OLD. Ensure NOPASSWD for systemctl." >&2
      exit 1
    fi
  else
    U="$(get_user_for_node "$NODE_OLD")"
    if ssh $SSH_OPTS "${U}@${NODE_OLD}" "sudo -n systemctl stop kubelet && sudo -n systemctl stop containerd"; then
      log_csv "2a" "kubelet/containerd stopped on $NODE_OLD via SSH as ${U}"
    else
      echo "❌ SSH or sudo failed for ${U}@${NODE_OLD}. Check key/sudoers." >&2
      exit 1
    fi
  fi
fi

# ---- Wait for rescheduling ----
echo "⏳ Waiting for new pod to be scheduled on the OTHER of the two nodes..."
OTHER_NODE="$([[ "$NODE_OLD" == "$NODE_A" ]] && echo "$NODE_B" || echo "$NODE_A")"
POD_NEW=""; NODE_NEW=""; START=$(date +%s)

while true; do
  POD_NEW=$(kubectl -n "$NAMESPACE" get pods -l "$APP_LABEL" -o json \
    | jq -r --arg old "$POD_OLD" '.items[] | select(.metadata.name != $old and .spec.nodeName != null) | .metadata.name' | head -n1)
  if [[ -n "$POD_NEW" ]]; then
    NODE_NEW=$(kubectl -n "$NAMESPACE" get pod "$POD_NEW" -o jsonpath='{.spec.nodeName}')
    if [[ "$NODE_NEW" == "$OTHER_NODE" ]]; then
      log_csv "3a" "New pod $POD_NEW scheduled on $NODE_NEW"
      break
    else
      echo "❌ New pod scheduled on unexpected node: $NODE_NEW" >&2
      exit 1
    fi
  fi
  (( $(date +%s) - START > 600 )) && { echo "❌ Timeout waiting for new pod scheduling" >&2; exit 1; }
  sleep 1
done

echo "⏳ Waiting for $POD_NEW to enter Running..."
until [[ "$(kubectl -n "$NAMESPACE" get pod "$POD_NEW" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")" == "Running" ]]; do
  sleep 1
done
log_csv "3b" "New pod entered Running phase on $NODE_NEW"

echo "⏳ Waiting for $POD_NEW to become Ready..."
until kubectl -n "$NAMESPACE" get pod "$POD_NEW" -o json \
  | jq -e '[.status.containerStatuses[] | select(.ready == true)] | length >= 1' >/dev/null; do
  sleep 1
done
log_csv "3c" "New pod became Ready on $NODE_NEW"

echo "✅ Experiment complete. Results saved to $RESULT_FILE"
