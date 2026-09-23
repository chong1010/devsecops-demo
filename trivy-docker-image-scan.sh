#!/bin/bash
IMAGE_NAME=$1

echo "Scanning built Docker image: ${IMAGE_NAME}"

# Run Trivy scan on CRITICAL vulnerabilities
docker run --rm -v $WORKSPACE:/root/.cache/ aquasec/trivy:0.17.2 -q image --exit-code 1 --severity CRITICAL $IMAGE_NAME

exit_code=$?

if [ $exit_code -eq 1 ]; then
    echo "Image scanning failed. CRITICAL vulnerabilities found."
    exit 1
else
    echo "Image scanning passed. No CRITICAL vulnerabilities found."
    exit 0
fi
