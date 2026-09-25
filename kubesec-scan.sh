#!/bin/bash

MANIFEST_FILE="k8s_deployment_service.yaml"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: $MANIFEST_FILE not found."
    exit 1
fi

echo "Scanning $MANIFEST_FILE with Kubesec..."

# 1. Perform SINGLE API request and store JSON output
SCAN_OUTPUT=$(curl -sSX POST --data-binary @"$MANIFEST_FILE" https://v2.kubesec.io/scan)

# 2. Parse response using jq
scan_message=$(echo "$SCAN_OUTPUT" | jq -r '.[0].message // "No message"')
scan_score=$(echo "$SCAN_OUTPUT" | jq -r '.[0].score // 0')

echo "Kubesec Message: $scan_message"
echo "Kubesec Score  : $scan_score"

# 3. Fail build only if score is 0 or negative (or adjust threshold as needed)
if [ "$scan_score" -gt 0 ]; then
    echo "Kubesec Scan Passed with score: $scan_score"
    exit 0
else
    echo "Kubesec Scan Failed! Security score ($scan_score) is too low."
    exit 1
fi