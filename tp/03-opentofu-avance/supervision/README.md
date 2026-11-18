# TP3 · Pile de supervision

> **Statut : à réaliser.** Ce dossier ne contient pas encore de sources ni de preuves.

## Objectif

Déployer une pile de supervision avec OpenTofu et prouver que les métriques et les journaux remontent.

## Éléments attendus

- Sources OpenTofu (`*.tf`), `terraform.tfvars.example`, `.terraform.lock.hcl`
- Preuve que la cible Prometheus est `UP` (page Targets ou `curl` sur l'API `/api/v1/targets`)
- Preuve qu'un journal de l'application est visible dans Grafana (capture anonymisée)

## Démarrage de la pile

```bash
cp terraform.tfvars.example terraform.tfvars   # renseigner les valeurs locales
tofu init
tofu validate
tofu plan -out=supervision.tfplan
tofu apply supervision.tfplan
```

## Arrêt de la pile

```bash
tofu plan -destroy -out=supervision-destroy.tfplan
tofu apply supervision-destroy.tfplan
```

## Résultats

À compléter après réalisation.
