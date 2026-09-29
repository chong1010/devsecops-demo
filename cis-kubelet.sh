#!/bin/bash
# cis-kubelet.sh

echo "Running CIS Kube-bench Benchmark Scan..."

# Run kube-bench container inside Minikube using a temporary pod
# We mount host directories (/var/lib/kubelet, /etc/systemd, /etc/kubernetes) to evaluate the node's CIS compliance
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

# Extract total fails from JSON output
if [ -f kube-bench-report.json ] && grep -q "total_fail" kube-bench-report.json; then
    total_fail=$(jq '.[].total_fail // 0' kube-bench-report.json | awk '{s+=$1} END {print s}')
    echo "CIS Benchmark Total Failures: ${total_fail}"

    if [ "$total_fail" -ne 0 ]; then
        echo "CIS Benchmark Failed Kubelet checks!"
        # Set to exit 0 if you want warnings without breaking the build, or exit 1 to enforce compliance
        exit 1
    else
        echo "CIS Benchmark Passed Kubelet checks successfully."
    fi
else
    echo "Warning: Unable to parse kube-bench-report.json or scan completed with non-zero output."
fi