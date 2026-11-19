#!/usr/bin/env bash
# Étape 3 : déploie une version avec OpenTofu. Sert aussi au retour arrière :
#   scripts/deploy.sh <version_precedente>
source "$(dirname "$0")/env.sh"
VERSION="${1:-$(default_version)}"

mkdir -p "$(dirname "$STATE_PATH")"
cd "$TP_DIR/infra"

tofu init -input=false -reconfigure -backend-config="path=${STATE_PATH}"
tofu fmt -check
tofu validate
tofu plan -input=false -var "api_version=${VERSION}" -out=deploy.tfplan
tofu apply -input=false deploy.tfplan
rm -f deploy.tfplan
tofu output
