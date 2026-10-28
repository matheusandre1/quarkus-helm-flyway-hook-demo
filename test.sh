#!/usr/bin/env bash
# Installs the Helm chart in Minikube, then upgrades it with a new application version (so a new image tag).
#
# Usage:
#   ./test.sh        -> with the fix (quarkus.helm.init-task-hook.enabled=true): the upgrade succeeds
#   ./test.sh false  -> without the fix: the upgrade fails because the Job is immutable
set -euo pipefail

HOOK_ENABLED="${1:-true}"
RELEASE=demo
CHART=target/helm/kubernetes/flyway-hook-demo

minikube status > /dev/null 2>&1 || minikube start
eval "$(minikube docker-env)"

helm uninstall "$RELEASE" --ignore-not-found > /dev/null
# Hook Jobs are not deleted by `helm uninstall`
kubectl delete job flyway-hook-demo-flyway-init --ignore-not-found > /dev/null

kubectl apply -f k8s/postgresql.yaml
kubectl rollout status deployment/postgresql --timeout=180s

build() {
  ./mvnw -B -q clean package -DskipTests \
    -Dquarkus.application.version="$1" \
    -Dquarkus.container-image.build=true \
    -Dquarkus.helm.init-task-hook.enabled="$HOOK_ENABLED"
}

check() {
  kubectl rollout status deployment/flyway-hook-demo --timeout=180s
  echo "Job image: $(kubectl get job flyway-hook-demo-flyway-init -o jsonpath='{.spec.template.spec.containers[0].image}')"
  kubectl port-forward deployment/flyway-hook-demo 8080:8080 > /dev/null &
  local pid=$!
  sleep 3
  echo "GET /hello: $(curl -s localhost:8080/hello)"
  kill "$pid"
}

echo "### Installing version 1.0.0 (init-task-hook.enabled=$HOOK_ENABLED)"
build 1.0.0
helm upgrade --install "$RELEASE" "$CHART"
check

echo "### Upgrading to version 1.0.1 (init-task-hook.enabled=$HOOK_ENABLED)"
build 1.0.1
helm upgrade "$RELEASE" "$CHART"
check

echo "### Upgrade succeeded"
