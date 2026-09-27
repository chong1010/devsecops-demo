#!/usr/bin/env bash
#
# trivy-k8s-scan.sh
# Trivy image scan for the Kubernetes (DevSecOps) pipeline.
#
# Two-phase scan, as in the KodeKloud "Demo Trivy Kubernetes" lesson:
#   1. LOW, MEDIUM, HIGH -> reported, but does NOT fail the build
#   2. CRITICAL           -> fails the build
#
# Usage:
#   bash trivy-k8s-scan.sh [image_name:tag]
#
# Image resolution order: $1  ->  $imageName  ->  $IMAGE_NAME:$IMAGE_TAG (Jenkins)
#
set -o nounset
set -o pipefail

# ----------------------------- configuration -----------------------------
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.17.2}"

IMAGE_TO_SCAN="${1:-${imageName:-${IMAGE_NAME:-}:${IMAGE_TAG:-}}}"
TRIVY_REPORT="${TRIVY_REPORT:-trivy-k8s-report.json}"

if [ -z "${IMAGE_TO_SCAN}" ] || [ "${IMAGE_TO_SCAN}" = ":" ]; then
    echo "[ERROR] No Docker image name provided."
    echo "Usage: bash trivy-k8s-scan.sh <image_name:tag>"
    exit 1
fi

# Cache on the workspace/shared folder so repeated runs are fast,
# temp dir on the higher-capacity disk (Vagrant VM)
CACHE_DIR="${WORKSPACE:-/vagrant/.cache/trivy}"
TEMP_DIR="${WORKSPACE:-/vagrant}/tmp"
mkdir -p "${CACHE_DIR}" "${TEMP_DIR}"

# ----------------------------- pre-checks --------------------------------
if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] docker command not found. Trivy scans the image via the Docker daemon."
    exit 1
fi

if ! docker image inspect "${IMAGE_TO_SCAN}" >/dev/null 2>&1; then
    echo "[ERROR] Image '${IMAGE_TO_SCAN}' is not present in the local Docker daemon."
    echo "        Run the 'Docker Build' stage before this scan."
    exit 1
fi

run_trivy() {
    # $1 = severity list, $2 = exit code to use
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "${CACHE_DIR}:/root/.cache/" \
        -v "${TEMP_DIR}:/tmp" \
        -e TRIVY_TEMP_DIR="/tmp" \
        "${TRIVY_IMAGE}" \
        -q image \
        --exit-code "$2" \
        --severity "$1" \
        "${IMAGE_TO_SCAN}"
}

echo "=========================================="
echo "[INFO] Trivy scanning image: ${IMAGE_TO_SCAN}"
echo "=========================================="

# ---- Phase 1: LOW / MEDIUM / HIGH (informational) -----------------------
echo "[INFO] Phase 1/2: reporting LOW, MEDIUM, HIGH vulnerabilities..."
if ! run_trivy "LOW,MEDIUM,HIGH" 0; then
    echo "[ERROR] Trivy failed to complete the scan (tool/runtime error)."
    exit 1
fi

# ---- Phase 2: CRITICAL (blocking gate) ----------------------------------
echo "[INFO] Phase 2/2: checking for CRITICAL vulnerabilities..."
set +e
run_trivy "CRITICAL" 1
exit_code=$?
set -e

echo "Exit Code : ${exit_code}"

case "${exit_code}" in
    0)
        echo "=========================================="
        echo "Image scanning passed. No CRITICAL vulnerabilities found."
        echo "=========================================="

        # Full JSON report (all severities) for auditing; never blocks the build
        docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "${CACHE_DIR}:/root/.cache/" \
            -v "${TEMP_DIR}:/tmp" \
            -e TRIVY_TEMP_DIR="/tmp" \
            -v "${PWD}:/out" \
            "${TRIVY_IMAGE}" \
            -q image \
            --format json \
            --output "/out/${TRIVY_REPORT}" \
            "${IMAGE_TO_SCAN}" || echo "[WARN] Could not generate JSON report."

        echo "[INFO] JSON report written to ${PWD}/${TRIVY_REPORT}"
        exit 0
        ;;
    1)
        echo "=========================================="
        echo "Image scanning failed. CRITICAL vulnerabilities found."
        echo "=========================================="
        exit 1
        ;;
    *)
        echo "[ERROR] Trivy exited unexpectedly with code ${exit_code}."
        exit "${exit_code}"
        ;;
esac
