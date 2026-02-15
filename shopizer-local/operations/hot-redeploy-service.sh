#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  hot-redeploy-service.sh -a <app_path> -s <service> [options]

Required:
  -a, --app-path       Path to multi-module app root (contains service dirs)
  -s, --service        Service/deployment name (e.g. users, merchants)

Options:
  -n, --namespace      Kubernetes namespace (default: default)
  -r, --registry       Registry host (default: 127.0.0.1:5001)
  -t, --tag            Image tag (default: dev-<timestamp>)
  --full-build         Run root mvnw clean install before service build
  --skip-push          Build image but do not docker push
  --rollout-timeout    Rollout wait timeout (default: 180s)
  -h, --help           Show this help

Examples:
  ./operations/hot-redeploy-service.sh \
    -a /Users/carlsamson/Documents/dev/workspace/shopizer \
    -s merchants

  ./operations/hot-redeploy-service.sh \
    -a /Users/carlsamson/Documents/dev/workspace/shopizer \
    -s users -n default -t dev-local
USAGE
}

APP_PATH=""
SERVICE=""
NAMESPACE="default"
REGISTRY="127.0.0.1:5001"
TAG="dev-$(date +%Y%m%d-%H%M%S)"
FULL_BUILD=0
SKIP_PUSH=0
ROLLOUT_TIMEOUT="180s"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--app-path)
      APP_PATH="$2"
      shift 2
      ;;
    -s|--service)
      SERVICE="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -r|--registry)
      REGISTRY="$2"
      shift 2
      ;;
    -t|--tag)
      TAG="$2"
      shift 2
      ;;
    --full-build)
      FULL_BUILD=1
      shift
      ;;
    --skip-push)
      SKIP_PUSH=1
      shift
      ;;
    --rollout-timeout)
      ROLLOUT_TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$APP_PATH" || -z "$SERVICE" ]]; then
  echo "--app-path and --service are required" >&2
  usage
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

APP_PATH="$(cd "$APP_PATH" && pwd)"
SERVICE_DIR="$APP_PATH/$SERVICE"

if [[ ! -d "$SERVICE_DIR" ]]; then
  echo "Service directory not found: $SERVICE_DIR" >&2
  exit 1
fi

if [[ ! -x "$APP_PATH/mvnw" ]]; then
  echo "mvnw not found or not executable at $APP_PATH/mvnw" >&2
  exit 1
fi

if [[ ! -x "$SERVICE_DIR/mvnw" ]]; then
  echo "mvnw not found or not executable at $SERVICE_DIR/mvnw" >&2
  exit 1
fi

if ! kubectl get deployment "$SERVICE" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Deployment '$SERVICE' not found in namespace '$NAMESPACE'" >&2
  exit 1
fi

IMAGE="$REGISTRY/shopizer-$SERVICE:$TAG"

JAVA_MAJOR_VERSION="$(java -XshowSettings:properties -version 2>&1 | awk '/java.specification.version/ {print $NF}' | cut -d. -f1)"
if [[ -z "$JAVA_MAJOR_VERSION" || "$JAVA_MAJOR_VERSION" -lt 21 ]]; then
  echo "Java 21+ is required (detected: ${JAVA_MAJOR_VERSION:-unknown})" >&2
  exit 1
fi

if [[ -x /usr/libexec/java_home ]]; then
  export JAVA_HOME
  JAVA_HOME=$(/usr/libexec/java_home -v 21)
fi

if [[ "$FULL_BUILD" -eq 1 ]]; then
  echo "Running root build in $APP_PATH"
  (
    cd "$APP_PATH"
    ./mvnw clean install -DskipTests
  )
fi

echo "Building service image: $IMAGE"
(
  cd "$SERVICE_DIR"
  ./mvnw clean package -DskipTests -Pno-tests
  ./mvnw spring-boot:build-image \
    -DskipTests \
    -Dspring-boot.build-image.imageName="$IMAGE" \
    -Dspring-boot.build-image.verbose=true \
    -Dspring-boot.build-image.environment=BP_JVM_VERSION=21 \
    -Pno-tests
)

if [[ "$SKIP_PUSH" -eq 0 ]]; then
  echo "Pushing image: $IMAGE"
  docker push "$IMAGE"
else
  echo "Skipping docker push (--skip-push)"
fi

echo "Updating deployment/$SERVICE image"
kubectl set image deployment/"$SERVICE" "$SERVICE"="$IMAGE" -n "$NAMESPACE"

echo "Waiting for rollout"
kubectl rollout status deployment/"$SERVICE" -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"

NEW_IMAGE="$(kubectl get deployment "$SERVICE" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[?(@.name=="'"$SERVICE"'")].image}')"

echo
echo "Redeploy complete"
echo "- Namespace: $NAMESPACE"
echo "- Deployment: $SERVICE"
echo "- Container: $SERVICE"
echo "- Image: $NEW_IMAGE"
