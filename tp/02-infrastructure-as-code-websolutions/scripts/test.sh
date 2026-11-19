#!/usr/bin/env bash
# Étape 1 : lance les tests de l'application dans l'étape "test" du Dockerfile.
# Un test en échec fait échouer le build, donc le script, donc le pipeline.
source "$(dirname "$0")/env.sh"

docker build --target test --progress=plain -t "${IMAGE_NAME}:test" "$TP_DIR/app"
echo "Tests OK"
