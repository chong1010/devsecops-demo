#!/bin/bash

chmod 777 $(pwd)

# Point directly to the active port-forwarded app endpoint on localhost
docker run --rm --net=host -v "$(pwd)":/zap/wrk/:rw -t ghcr.io/zaproxy/zaproxy:weekly zap-api-scan.py \
  -t "http://127.0.0.1:8082/v3/api-docs" \
  -f openapi \
  -c zap_rules \
  -r zap_report.html

exit_code=$?

echo "Exit Code : $exit_code"

# Exit code 0 = PASS
# Exit code 2 = WARN (Low risks / Infos / Warnings) -> Allow build to succeed
if [[ ${exit_code} -eq 0 ]] || [[ ${exit_code} -eq 2 ]]; then
    echo "OWASP ZAP Scan passed (No High/Medium risks triggered)."
    exit 0
else
    echo "OWASP ZAP Scan failed due to High/Medium security risk or scan error."
    exit 1
fi