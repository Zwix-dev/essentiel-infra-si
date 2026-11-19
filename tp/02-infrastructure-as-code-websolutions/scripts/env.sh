#!/usr/bin/env bash
# Paramètres communs aux scripts du pipeline. Surchargeables par variables d'environnement.
set -euo pipefail

TP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_HOST="${VM_HOST:-192.168.56.20}"
VM_USER="${VM_USER:-vboxuser}"
DOCKER_VM="ssh://${VM_USER}@${VM_HOST}"
IMAGE_NAME="${IMAGE_NAME:-websolutions-api}"
# État OpenTofu hors du dépôt, partagé entre exécutions manuelles et runner
STATE_PATH="${STATE_PATH:-$HOME/.websolutions/test/infra.tfstate}"

# Version livrée = SHA court du commit (artefact identifié et traçable)
default_version() {
  git -C "$TP_DIR" rev-parse --short=7 HEAD
}
