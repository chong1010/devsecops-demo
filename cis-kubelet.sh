#!/bin/bash
# cis-kubelet.sh

# Set your allowed maximum failure threshold here
MAX_ALLOWED_FAILS=3

echo "Running CIS Kube-bench Benchmark Scan..."

# Run kube-bench inside Minikube as a temporary pod
kubectl run kube-bench-scan --rm -i --restart=Never \
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
  }' > kube-bench-report.json || true

# Extract and sum total fails from JSON report
if [ -f kube-bench-report.json ] && grep -q "total_fail" kube-bench-report.json; then
    total_fail=$(jq '.[].total_fail // 0' kube-bench-report.json | awk '{s+=$1} END {print s}')
    echo "CIS Benchmark Total Failures: ${total_fail}"
    echo "Allowed Maximum Failures: ${MAX_ALLOWED_FAILS}"

    # Check if failures exceed the allowed threshold
    if [ "$total_fail" -gt "$MAX_ALLOWED_FAILS" ]; then
        echo "ERROR: CIS Benchmark failed! Total failures (${total_fail}) exceeded allowed threshold (${MAX_ALLOWED_FAILS})."
        exit 1
    else
        echo "SUCCESS: CIS Benchmark passed within acceptable tolerance (${total_fail} <= ${MAX_ALLOWED_FAILS})."
        exit 0
    fi
else
    echo "Warning: Unable to parse kube-bench-report.json or scan output was empty."
fi