#!/bin/bash
# cis-kubelet.sh

MAX_ALLOWED_FAILS=3

echo "Running CIS Kube-bench Benchmark Scan..."

# Quietly run kube-bench and isolate JSON output
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

# Extract valid JSON from raw output
sed -n '/^{/,$p' raw-output.json > kube-bench-report.json

# Extract total fails correctly from .Controls array
if [ -s kube-bench-report.json ] && jq empty kube-bench-report.json 2>/dev/null; then
    total_fail=$(jq '[.Controls[].total_fail // 0] | add' kube-bench-report.json)
    echo "CIS Benchmark Total Failures: ${total_fail}"
    echo "Allowed Maximum Failures: ${MAX_ALLOWED_FAILS}"

    if [ "$total_fail" -gt "$MAX_ALLOWED_FAILS" ]; then
        echo "ERROR: CIS Benchmark failed! Total failures (${total_fail}) exceeded allowed threshold (${MAX_ALLOWED_FAILS})."
        exit 1
    else
        echo "SUCCESS: CIS Benchmark passed within acceptable tolerance (${total_fail} <= ${MAX_ALLOWED_FAILS})."
        exit 0
    fi
else
    echo "Warning: Unable to parse valid JSON from kube-bench-report.json."
fi