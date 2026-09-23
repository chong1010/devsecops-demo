#!/bin/bash

# Use argument $1 if provided; otherwise, fallback to Jenkins environment variables
IMAGE_TO_SCAN="${1:-${IMAGE_NAME}:${IMAGE_TAG}}"

if [ -z "$IMAGE_TO_SCAN" ] || [ "$IMAGE_TO_SCAN" == ":" ]; then
    echo "Error: No Docker image name provided."
    echo "Usage: bash trivy-docker-image-scan.sh <image_name:tag>"
    exit 1
fi

echo "Scanning built Docker image: ${IMAGE_TO_SCAN}"

# Run Trivy with Docker socket mounted so it can inspect local images
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $WORKSPACE:/root/.cache/ \
  aquasec/trivy:0.74.0 -q image \
  --exit-code 1 \
  --severity CRITICAL \
  "${IMAGE_TO_SCAN}"

exit_code=$?

if [ $exit_code -eq 1 ]; then
    echo "Image scanning failed. CRITICAL vulnerabilities found."
    exit 1
else
    echo "Image scanning passed. No CRITICAL vulnerabilities found."
    exit 0
fi
