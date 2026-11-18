# TP2 · Infrastructure as Code pour WebSolutions

> **Statut : à réaliser.** Ce dossier ne contient pas encore de sources ni de preuves.

## Objectif

Pour WebSolutions, provisionner l'infrastructure, configurer les services et démontrer un pipeline qui teste et déploie en environnement de test.

## Éléments attendus

| Élément | Fichier prévu |
|---------|---------------|
| Code IaC (provisionnement) | `infra/` (`*.tf`, `terraform.tfvars.example`, `.terraform.lock.hcl`) |
| Configuration des services | `config/` (playbooks ou manifestes) |
| Tests | `tests/` |
| Définition du pipeline | fichier du moteur choisi (ex. `Jenkinsfile`) |
| Preuve d'échec | exécution où un test en échec **bloque** le déploiement |
| Preuve de succès | exécution réussie avec contrôle de santé |

## Secrets

Jetons Git, Jenkins ou SonarQube et mots de passe : uniquement dans les secrets du moteur de pipeline ou dans un fichier local ignoré. Seuls les modèles `.env.example` et `terraform.tfvars.example` sont versionnés.

## Prérequis, commandes, résultats attendus et nettoyage

À compléter après réalisation.
