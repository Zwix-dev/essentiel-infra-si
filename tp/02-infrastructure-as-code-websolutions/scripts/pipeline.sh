#!/usr/bin/env bash
# Chaîne complète, identique au workflow GitHub Actions : test, build, deploy, santé.
# Usage : TF_VAR_db_password=... scripts/pipeline.sh [version]
source "$(dirname "$0")/env.sh"
VERSION="${1:-$(default_version)}"
DIR="$(dirname "$0")"

echo "== Version livrée : ${VERSION}"
"$DIR/test.sh"
"$DIR/build.sh" "$VERSION"
"$DIR/deploy.sh" "$VERSION"
"$DIR/healthcheck.sh" "$VERSION"
