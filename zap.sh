#!/bin/bash

# Use Jenkins' injected KUBECONFIG if available, otherwise check standard locations
if [ -z "$KUBECONFIG" ]; then
    if [ -f "/home/vagrant/.kube/config" ] && [ -r "/home/vagrant/.kube/config" ]; then
        export KUBECONFIG="/home/vagrant/.kube/config"
    fi
fi

SERVICE_NAME="${serviceName:-devsecops-svc}"
APP_URL="${applicationURL:-http://192.168.49.2}"

# Query the NodePort using JSONPath directly
PORT=$(kubectl -n default get svc "${SERVICE_NAME}" -o jsonpath='{.spec.ports[0].nodePort}')

if [ -z "$PORT" ] || [ "$PORT" == "null" ]; then
    echo "ERROR: Could not retrieve NodePort for service ${SERVICE_NAME}"
    exit 1
fi

echo "Targeting OWASP ZAP Scan at: ${APP_URL}:${PORT}/v3/api-docs"

chmod 777 "$(pwd)"

docker run --rm --net=host -v "$(pwd)":/zap/wrk/:rw -t ghcr.io/zaproxy/zaproxy:weekly zap-api-scan.py \
  -t "${APP_URL}:${PORT}/v3/api-docs" \
  -f openapi \
  -c zap_rules \
  -r zap_report.html

exit_code=$?

echo "Exit Code : $exit_code"

if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 2 ]]; then
    echo "OWASP ZAP Scan passed."
    exit 0
else
    echo "OWASP ZAP Scan failed due to security risks or scan error."
    exit 1
fi