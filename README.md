# Essentiels de l'infrastructure du SI

Dépôt de rendu des travaux pratiques du module **Essentiels de l'infrastructure du SI** (CESI).

Le dépôt rassemble, pour chaque atelier et chaque TP, les sources et configurations (Docker, Compose, OpenTofu, Puppet, Ansible, Kubernetes), les instructions pour rejouer l'exercice et les preuves des vérifications (extraits de sortie relus et captures anonymisées).

Parcours : du service local (conteneur, VM, réseau, stockage) jusqu'à l'infrastructure automatisée (Infrastructure as Code, gestion de configuration, pipeline).

## Table des ateliers et TP

### Ateliers · Infrastructure et virtualisation

| Id | Atelier | Dossier | Outils | Statut |
|----|---------|---------|--------|--------|
| A1 | MongoDB avec Docker | [`ateliers/a1-mongodb-docker`](ateliers/a1-mongodb-docker/) | Docker, Compose | Réalisé |
| A2 | VM Linux et conteneur web | [`ateliers/a2-vm-linux-conteneur-web`](ateliers/a2-vm-linux-conteneur-web/) | VirtualBox, Ubuntu Server, Docker | Réalisé |
| A3 | Connecter une VM | [`ateliers/a3-reseau-vm`](ateliers/a3-reseau-vm/) | VirtualBox, Netplan | Réalisé |
| A4 | Stockage virtuel et montage d'un disque | [`ateliers/a4-stockage-virtuel`](ateliers/a4-stockage-virtuel/) | VirtualBox, fdisk, ext4, fstab | Réalisé (test après redémarrage à consigner) |
| A5 | Déployer Nginx avec Minikube | [`ateliers/a5-nginx-minikube`](ateliers/a5-nginx-minikube/) | Minikube, kubectl | Réalisé |

### Ateliers · Automatisation de l'infrastructure

| Id | Atelier | Dossier | Outils | Statut |
|----|---------|---------|--------|--------|
| B1 | Déployer Nginx avec OpenTofu | [`ateliers/b1-nginx-opentofu`](ateliers/b1-nginx-opentofu/) | OpenTofu, fournisseur Docker | Réalisé (plan sans changement à consigner) |
| B2 | Catalogue Node.js, PostgreSQL et Redis | [`ateliers/b2-catalogue-node-postgres-redis`](ateliers/b2-catalogue-node-postgres-redis/) | OpenTofu, Docker, Node.js | Réalisé (relecture après redémarrage de la base à consigner) |
| B3 | Configurer Nginx avec Puppet | [`ateliers/b3-nginx-puppet`](ateliers/b3-nginx-puppet/) | Puppet (`puppet apply`) | Réalisé |
| B4 | Déployer Nginx avec Ansible | [`ateliers/b4-nginx-ansible`](ateliers/b4-nginx-ansible/) | Ansible | Réalisé |

### Travaux pratiques

| Id | TP | Dossier | Statut |
|----|----|---------|--------|
| TP1 | Docker et Minikube : image Node.js vérifiée sous Docker puis Kubernetes | [`tp/01-docker-minikube-node`](tp/01-docker-minikube-node/) | Réalisé |
| TP2 | Infrastructure as Code pour WebSolutions : provisionnement, configuration, pipeline de test et de déploiement | [`tp/02-infrastructure-as-code-websolutions`](tp/02-infrastructure-as-code-websolutions/) | Code livré, exécution sur la VM à consigner |
| TP3 | OpenTofu avancé : plateforme DevSecOps | [`tp/03-opentofu-avance/devsecops`](tp/03-opentofu-avance/devsecops/) | Réalisé |
| TP3 | OpenTofu avancé : pile de supervision | [`tp/03-opentofu-avance/supervision`](tp/03-opentofu-avance/supervision/) | Réalisé |

## Organisation du dépôt

```
essentiels-infrastructure-si/
  README.md
  .gitignore
  ateliers/
    a1-mongodb-docker/
    a2-vm-linux-conteneur-web/
    a3-reseau-vm/
    a4-stockage-virtuel/
    a5-nginx-minikube/
    b1-nginx-opentofu/
    b2-catalogue-node-postgres-redis/
    b3-nginx-puppet/
    b4-nginx-ansible/
  tp/
    01-docker-minikube-node/
    02-infrastructure-as-code-websolutions/
    03-opentofu-avance/
      devsecops/
      supervision/
```

Chaque dossier contient un `README.md` qui précise :

- les **prérequis** (outils, versions, VM utilisée) ;
- les **commandes à exécuter**, dans l'ordre ;
- les **résultats attendus** et les résultats réellement obtenus ;
- le **nettoyage** des ressources créées.
