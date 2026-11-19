#!/usr/bin/env bash
# Étape 2 : construit l'image livrée directement sur le moteur Docker de la VM de test.
source "$(dirname "$0")/env.sh"
VERSION="${1:-$(default_version)}"

DOCKER_HOST="$DOCKER_VM" docker build \
  --label "org.opencontainers.image.version=${VERSION}" \
  -t "${IMAGE_NAME}:${VERSION}" "$TP_DIR/app"

DOCKER_HOST="$DOCKER_VM" docker image ls "$IMAGE_NAME"
echo "Image ${IMAGE_NAME}:${VERSION} disponible sur ${VM_HOST}"
