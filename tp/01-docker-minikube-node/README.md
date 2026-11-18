# TP1 · Docker et Minikube avec Node.js

> **Statut : à réaliser.** Ce dossier ne contient pas encore de sources ni de preuves.

## Objectif

Construire une image Node.js, puis vérifier que le même service donne le même résultat HTTP sous Docker puis dans Kubernetes (Minikube).

## Éléments attendus

| Élément | Fichier prévu |
|---------|---------------|
| Code de l'application | `app/` (`server.js`, `package.json`) |
| Image | `Dockerfile` |
| Manifestes Kubernetes | `k8s/` (Deployment, Service) |
| Preuve Docker | sortie de `curl` sur le conteneur |
| Preuve Kubernetes | état des Pods et sortie de `curl` via `port-forward` |

## Prérequis

- Docker Desktop, Minikube (profil dédié), voir [A5](../../ateliers/a5-nginx-minikube/)

## Commandes, résultats attendus et nettoyage

À compléter après réalisation :

1. `docker build` puis `docker run`, `curl` sur le port publié.
2. Chargement de l'image dans Minikube (`minikube image load`), `kubectl apply -f k8s/`, `rollout status`.
3. `port-forward` puis `curl` : réponse identique à l'étape 1.
4. Nettoyage : `docker rm -f`, `kubectl delete -f k8s/`, `minikube delete -p <profil>`.
