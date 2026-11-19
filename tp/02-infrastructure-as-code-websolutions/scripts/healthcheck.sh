#!/usr/bin/env bash
# Étape 4 : contrôle de santé à travers Nginx et vérification de la version servie.
source "$(dirname "$0")/env.sh"
EXPECTED="${1:-$(default_version)}"
URL="http://${VM_HOST}/health"

for attempt in $(seq 1 10); do
  if body="$(curl -fsS --max-time 3 "$URL")"; then
    echo "$body"
    status="$(echo "$body" | jq -r .status)"
    version="$(echo "$body" | jq -r .version)"
    if [ "$status" = "ok" ] && [ "$version" = "$EXPECTED" ]; then
      echo "Santé OK : version ${version} servie sur ${URL}"
      exit 0
    fi
    echo "Réponse inattendue (status=${status}, version=${version}, attendue=${EXPECTED})"
  fi
  echo "Tentative ${attempt}/10 échouée, nouvel essai dans 3 s"
  sleep 3
done

echo "Échec du contrôle de santé sur ${URL}" >&2
exit 1
