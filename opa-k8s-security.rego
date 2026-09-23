package main

import rego.v1

deny contains msg if {
  input.kind == "Service"
  input.spec.type != "NodePort"
  msg := "Service type should be NodePort"
}

deny contains msg if {
  input.kind == "Deployment"
  not input.spec.template.spec.containers[0].securityContext.runAsNonRoot
  msg := "Containers must not run as root - use runAsNonRoot within container security context"
}
