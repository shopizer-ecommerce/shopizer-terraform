#!/bin/bash
set -e


APP_PATH=$1
shift
SERVICES=("$@")

echo path: $APP_PATH
echo pwd: $(pwd)

java_version_output=$(java -version 2>&1)

echo "$java_version_output"

JAVA_MAJOR_VERSION=$(java -XshowSettings:properties -version 2>&1 \
  | grep 'java.specification.version' \
  | awk '{print $NF}' \
  | cut -d. -f1)

echo "Detected Java major version: $JAVA_MAJOR_VERSION"

# Require Java 21 or newer
if [[ "$JAVA_MAJOR_VERSION" -lt 21 ]]; then
  echo "❌ Java version must be 21 or newer. Aborting."
  exit 1
else
  echo "✅ Java version is supported."
fi

# Pin JAVA_HOME to 21 if available (macOS) so downstream tools don't drift
if [[ -x /usr/libexec/java_home ]]; then
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)
fi


REGISTRY="127.0.0.1:5001"

echo "Detected project version: $POM_VERSION"

cd "$APP_PATH"
 ./mvnw clean install -DskipTests


#for service in "$@"; do
for service in "${SERVICES[@]}"; do
  SERVICE_DIR="$APP_PATH/$service"


  echo "📁 Entering $SERVICE_DIR"
  cd "$SERVICE_DIR"
  POM_VERSION=latest

  echo "📁 version $POM_VERSION"


  echo "🔨 Building image for shopizer-$service"
  #./mvnw clean package -DskipTests
  ./mvnw spring-boot:build-image  -DskipTests -Dspring-boot.build-image.imageName=$REGISTRY/shopizer-$service:$POM_VERSION -Dspring-boot.build-image.verbose=true -Dspring-boot.build-image.environment=BP_JVM_VERSION=21 -Pno-tests
  echo "📤 Pushing $REGISTRY/shopizer-$service:$POM_VERSION"
  docker push $REGISTRY/shopizer-$service:$POM_VERSION
  cd - > /dev/null
done
