#!/bin/bash
# k8s-deployment-rollout-status.sh

# Use the environment variable if set, otherwise default to "default"
NAMESPACE="${K8S_NAMESPACE:-default}"
DEPLOYMENT="${deploymentName:-devsecops}"
TIMEOUT="${ROLLOUT_TIMEOUT:-3m}"

echo "Checking rollout status for deployment '${DEPLOYMENT}' in namespace '${NAMESPACE}'..."

# Allow time for pods to start initializing
sleep 10s

# Monitor rollout status directly using kubectl's exit status
if kubectl rollout status deployment/"${DEPLOYMENT}" -n "${NAMESPACE}" --timeout="${TIMEOUT}"; then
    echo "Deployment ${DEPLOYMENT} rollout succeeded."
    exit 0
else
    echo "Deployment ${DEPLOYMENT} rollout failed or timed out. Rolling back..."
    kubectl rollout undo deployment/"${DEPLOYMENT}" -n "${NAMESPACE}"
    exit 1
fi