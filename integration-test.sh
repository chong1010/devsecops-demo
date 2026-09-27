#!/bin/bash
# integration-test.sh

sleep 5s

# Extract NodePort from the Kubernetes Service
PORT=$(kubectl -n default get svc "${serviceName}" -o json | jq .spec.ports[].nodePort)

echo "Discovered NodePort: ${PORT}"
echo "Testing endpoint: ${applicationURL}:${PORT}${applicationURI}"

if [[ -n "$PORT" && "$PORT" != "null" ]]; then

    response=$(curl -s "${applicationURL}:${PORT}${applicationURI}")
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "${applicationURL}:${PORT}${applicationURI}")

    # Application return verification (numeric app checks)
    if [[ "$response" == "100" ]]; then
        echo "Increment Test Passed (Response: $response)"
    else
        echo "Increment Test Failed (Expected: 100, Got: $response)"
        exit 1
    fi

    # HTTP Status code verification
    if [[ "$http_code" == "200" ]]; then
        echo "HTTP Status Code Test Passed ($http_code)"
    else
        echo "HTTP Status code is not 200 (Got: $http_code)"
        exit 1
    fi

else
    echo "ERROR: The Service '${serviceName}' does not have a valid NodePort assigned."
    exit 1
fi