#!/bin/bash

PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)

# Run OWASP ZAP API Scan
docker run --rm -v "$(pwd)":/zap/wrk/:rw -t owasp/zap2docker-weekly zap-api-scan.py \
  -t "$applicationURL:$PORT/v3/api-docs" \
  -f openapi \
  -c zap_rules \
  -r zap_report.html

exit_code=$?

echo "Exit Code : $exit_code"

if [[ ${exit_code} -ne 0 ]]; then
    echo "OWASP ZAP Report has either Low/Medium/High Risk. Please check the HTML Report"
    exit 1
else
    echo "OWASP ZAP did not report any Risk"
fi