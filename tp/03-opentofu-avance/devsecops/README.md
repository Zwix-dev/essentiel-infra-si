# TP3 · Pile DevSecOps

> **Statut : à réaliser.** Ce dossier ne contient pas encore de sources ni de preuves.

## Objectif

Déployer une plateforme DevSecOps avec OpenTofu et vérifier chacun de ses services.

## Éléments attendus

- Sources OpenTofu (`*.tf`), `terraform.tfvars.example`, `.terraform.lock.hcl`
- Vérification de chaque service (commande + résultat)

## Démarrage de la pile

```bash
cp terraform.tfvars.example terraform.tfvars   # renseigner les valeurs locales
tofu init
tofu validate
tofu plan -out=devsecops.tfplan
tofu apply devsecops.tfplan
```

## Arrêt de la pile

```bash
tofu plan -destroy -out=devsecops-destroy.tfplan
tofu apply devsecops-destroy.tfplan
```

## Résultats

À compléter après réalisation.
