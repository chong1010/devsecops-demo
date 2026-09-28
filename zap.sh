#!/bin/bash

PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)

chmod 777 $(pwd)

# Added --net=host to allow direct access to Minikube IP (192.168.49.2)
docker run --rm --net=host -v "$(pwd)":/zap/wrk/:rw -t ghcr.io/zaproxy/zaproxy:weekly zap-api-scan.py \
  -t "$applicationURL:$PORT/v3/api-docs" \
  -f openapi \
  -c zap_rules \
  -r zap_report.html

exit_code=$?

echo "Exit Code : $exit_code"

if [[ ${exit_code} -ne 0 ]]; then
    echo "OWASP ZAP Scan failed or found vulnerabilities."
    exit 1
else
    echo "OWASP ZAP did not report any Risk"
fi