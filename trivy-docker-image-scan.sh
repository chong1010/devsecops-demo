#!/bin/bash
IMAGE_NAME=$1

if [ -z "$IMAGE_NAME" ]; then
    echo "Error: No Docker image name provided."
    echo "Usage: bash trivy-docker-image-scan.sh <image_name:tag>"
    exit 1
fi

echo "Scanning built Docker image: ${IMAGE_NAME}"

# Run Trivy v0.74.0 scanning for CRITICAL vulnerabilities
docker run --rm \
  -v $WORKSPACE:/root/.cache/ \
  aquasec/trivy:0.74.0 -q image \
  --exit-code 1 \
  --severity CRITICAL \
  "${IMAGE_NAME}"

exit_code=$?

if [ $exit_code -eq 1 ]; then
    echo "Image scanning failed. CRITICAL vulnerabilities found."
    exit 1
else
    echo "Image scanning passed. No CRITICAL vulnerabilities found."
    exit 0
fi
