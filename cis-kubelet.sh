#!/bin/bash
# cis-kubelet.sh

MAX_ALLOWED_FAILS=3

echo "Running CIS Kube-bench Benchmark Scan..."

# Quietly run kube-bench and isolate raw output
kubectl run kube-bench-scan --rm -i --quiet --restart=Never \
  --image=aquasec/kube-bench:latest \
  --overrides='{
    "spec": {
      "hostPID": true,
      "containers": [{
        "name": "kube-bench",
        "image": "aquasec/kube-bench:latest",
        "args": ["run", "--targets", "node", "--json"],
        "volumeMounts": [
          {"name": "var-lib-kubelet", "mountPath": "/var/lib/kubelet", "readOnly": true},
          {"name": "etc-systemd", "mountPath": "/etc/systemd", "readOnly": true},
          {"name": "etc-kubernetes", "mountPath": "/etc/kubernetes", "readOnly": true}
        ]
      }],
      "volumes": [
        {"name": "var-lib-kubelet", "hostPath": {"path": "/var/lib/kubelet"}},
        {"name": "etc-systemd", "hostPath": {"path": "/etc/systemd"}},
        {"name": "etc-kubernetes", "hostPath": {"path": "/etc/kubernetes"}}
      ]
    }
  }' > raw-output.json 2>/dev/null || true

# Extract valid JSON starting from opening brace
sed -n '/^{/,$p' raw-output.json > raw-bench.json

# Filter out PASS results and construct a clean report with only FAIL and WARN
if [ -s raw-bench.json ] && jq empty raw-bench.json 2>/dev/null; then
    
    # 1. Generate filtered report (FAIL & WARN only)
    jq '
      .Controls[] |= (
        .tests[] |= (
          .results |= map(select(.status == "FAIL" or .status == "WARN"))
        ) | .tests |= map(select(.results | length > 0))
      ) | .Controls |= map(select(.tests | length > 0))
    ' raw-bench.json > kube-bench-report.json

    # Clean up temporary raw files
    rm -f raw-output.json raw-bench.json

    # 2. Count total fails from raw/filtered JSON
    total_fail=$(jq '[.Controls[].tests[].results[] | select(.status=="FAIL")] | length' kube-bench-report.json)
    total_warn=$(jq '[.Controls[].tests[].results[] | select(.status=="WARN")] | length' kube-bench-report.json)

    echo "--- Kube-bench Scan Summary ---"
    echo "Critical Failures (FAIL)  : ${total_fail}"
    echo "Non-Critical Warnings (WARN): ${total_warn}"
    echo "Allowed Failure Threshold : ${MAX_ALLOWED_FAILS}"

    # Print filtered findings cleanly in pipeline console logs
    echo "--- Filtered Findings ---"
    jq -r '.Controls[].tests[].results[] | "[\(.status)] \(.test_number) - \(.test_desc)"' kube-bench-report.json

    # 3. Fail pipeline if critical failures exceed threshold
    if [ "$total_fail" -gt "$MAX_ALLOWED_FAILS" ]; then
        echo "ERROR: CIS Benchmark failed! Total failures (${total_fail}) exceeded allowed threshold (${MAX_ALLOWED_FAILS})."
        exit 1
    else
        echo "SUCCESS: CIS Benchmark passed within acceptable tolerance (${total_fail} <= ${MAX_ALLOWED_FAILS})."
        exit 0
    fi
else
    echo "Warning: Unable to parse valid JSON from scan output."
    exit 1
fi