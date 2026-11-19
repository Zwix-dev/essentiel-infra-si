# TP2 · Infrastructure as Code pour WebSolutions

## Le besoin

WebSolutions veut des environnements cohérents du développement à la production. Une application représentative doit traverser toute la chaîne : provisionnement, configuration, tests, puis déploiement dans un environnement de **test**.

Ici, l'application est une petite API Node.js avec PostgreSQL, derrière un Nginx. La cible de test est la VM VirtualBox `UbuntuDev` des ateliers (A2/A3), joignable depuis le Mac en `192.168.56.20`.

## Architecture

```
 Mac (poste de contrôle + runner)                 VM UbuntuDev 192.168.56.20 (env. de test)
 ┌──────────────────────────────┐   SSH   ┌──────────────────────────────────────────────────┐
 │ Ansible ─────────────────────┼────────►│ ufw : 22 et 80 ouverts, reste refusé              │
 │                              │         │ Nginx (hôte) :80 ── reverse proxy ──┐             │
 │ OpenTofu ── ssh:// ──────────┼────────►│ Docker                              ▼             │
 │                              │         │   réseau websolutions-test-net                    │
 │ Pipeline (GitHub Actions,    │         │   ├─ websolutions-test-api   127.0.0.1:3000       │
 │ runner auto-hébergé)         │         │   └─ websolutions-test-db    (aucun port publié)  │
 │                              │         │        └─ volume websolutions-test-pgdata          │
 └──────────────────────────────┘         └──────────────────────────────────────────────────┘
                 navigateur / curl ── http://192.168.56.20/health ──► Nginx ──► API ──► PostgreSQL
```

Flux autorisés :

| De | Vers | Port | Pourquoi |
|----|------|------|----------|
| Mac | VM | 22 | Ansible, OpenTofu (Docker via SSH), build de l'image |
| Mac / navigateur | Nginx (VM) | 80 | seul point d'entrée HTTP |
| Nginx | API | 3000 sur `127.0.0.1` | l'API n'est pas exposée hors de la VM |
| API | PostgreSQL | 5432 sur le réseau Docker | la base n'est joignable que par l'API |

## Trois couches, trois outils

| Couche | Outil | Ce qu'il gère | Dossier |
|--------|-------|---------------|---------|
| Provisionnement | OpenTofu + fournisseur `kreuzwerker/docker` | réseau, volume de la base, conteneurs PostgreSQL et API, sorties d'accès | [`infra/`](infra/) |
| Configuration | Ansible | paquets (Nginx, ufw, Docker), droits Docker du compte, fichier de config Nginx, services, pare-feu | [`ansible/`](ansible/) |
| Livraison | GitHub Actions (runner auto-hébergé sur le Mac) + scripts | tests, image versionnée, déploiement, contrôle de santé | [`scripts/`](scripts/), [`.github/workflows/tp02-websolutions.yml`](../../.github/workflows/tp02-websolutions.yml) |

Pourquoi ce découpage : Ansible prépare **le système** de la VM (ce qui ne change presque jamais), OpenTofu décrit **les ressources** de l'application (ce qui change à chaque version), et le pipeline enchaîne les deux de façon automatique. Nginx est sur l'hôte, géré par Ansible, comme dans les ateliers B3/B4 : c'est un vrai service système avec son fichier de configuration.

## Arborescence

```
02-infrastructure-as-code-websolutions/
├── app/                      API Node.js
│   ├── src/app.js            routes /health et /api/projects (testables sans base)
│   ├── src/server.js         connexion PostgreSQL, données initiales, écoute 3000
│   ├── test/app.test.js      4 tests (node:test)
│   ├── Dockerfile            étapes deps → test → runtime
│   └── package.json / package-lock.json
├── infra/                    OpenTofu
│   ├── versions.tf           fournisseur Docker pointé sur la VM en ssh://
│   ├── variables.tf          entrées (VM, version, base)
│   ├── main.tf               réseau, volume, images, conteneurs
│   ├── outputs.tf            URL, image déployée, volume à sauvegarder
│   ├── terraform.tfvars.example
│   └── .terraform.lock.hcl
├── ansible/
│   ├── ansible.cfg, inventory.ini, group_vars/targets.yml
│   ├── playbook.yml
│   └── templates/websolutions.conf.j2
└── scripts/                  étapes du pipeline, utilisables à la main
    ├── env.sh                paramètres communs
    ├── test.sh  build.sh  deploy.sh  healthcheck.sh
    └── pipeline.sh           chaîne complète en local
```

## Prérequis

Sur le Mac :

- Docker Desktop, OpenTofu ≥ 1.8 (`brew install opentofu`), Ansible avec `community.general` (`brew install ansible`), `jq`, `curl`
- Une clé SSH vers la VM, sans mot de passe ou chargée dans l'agent (`ssh-add`)

Sur la VM `UbuntuDev` (ateliers A2 + A3) :

- Adresse privée `192.168.56.20` (réseau privé hôte), `openssh-server`, compte `vboxuser` avec `sudo`
- 2 Go de RAM suffisent pour Nginx + API + PostgreSQL

Vérification de l'accès :

```bash
ssh-copy-id vboxuser@192.168.56.20      # une seule fois
ssh vboxuser@192.168.56.20 true
```

## 0. Secrets

Rien de secret n'est versionné.

```bash
cp infra/terraform.tfvars.example infra/terraform.tfvars   # ignoré par Git
# éditer db_password
```

Dans le pipeline, le mot de passe vient du secret GitHub `WEBSOLUTIONS_DB_PASSWORD` (environnement `test`), passé à OpenTofu par `TF_VAR_db_password`.

> Le mot de passe se retrouve quand même en clair dans l'état OpenTofu. C'est pour ça que l'état est rangé hors du dépôt, dans `~/.websolutions/test/infra.tfstate`.

## 1. Configurer la VM (Ansible)

On commence par la configuration, car OpenTofu a besoin de Docker et des droits du compte sur la VM.

```bash
cd ansible
ansible -m ansible.builtin.ping targets
ansible-playbook playbook.yml --syntax-check
ansible-playbook playbook.yml -K              # 1re application
ansible-playbook playbook.yml -K              # 2e application
ansible-playbook playbook.yml -K --check --diff
```

Ce que fait le playbook :

- **paquets** : `nginx`, `ufw`, `curl`, et `docker.io` seulement si aucun moteur Docker n'est déjà là ;
- **droits** : ajoute `vboxuser` au groupe `docker`, ce qui permet à OpenTofu et au pipeline de piloter Docker en SSH sans `sudo` ;
- **fichiers** : `/etc/nginx/sites-available/websolutions.conf` (reverse proxy vers `127.0.0.1:3000`), le lien dans `sites-enabled`, la suppression du site par défaut et un fichier témoin `/etc/websolutions/environnement.txt` ;
- **services** : `nginx -t` avant le rechargement, puis `nginx` et `docker` démarrés et activés ;
- **pare-feu** : SSH puis 80 autorisés, tout le reste refusé en entrée.

**Attendu :**

- 1re application : plusieurs tâches en `changed` (fichier Nginx, groupe docker, ufw…) et le handler `Recharger Nginx` déclenché ;
- 2e application : `changed=0` dans le `PLAY RECAP`, rien n'a bougé.

La différence entre les deux : `ok` veut dire que la tâche a vérifié que la cible était déjà conforme, `changed` veut dire qu'elle a réellement modifié quelque chose.

### Remise en conformité

```bash
ssh vboxuser@192.168.56.20 'echo "modifié à la main" | sudo tee /etc/websolutions/environnement.txt'
ansible-playbook playbook.yml -K --check --diff   # montre l'écart
ansible-playbook playbook.yml -K                  # le corrige : 1 changed
ssh vboxuser@192.168.56.20 cat /etc/websolutions/environnement.txt
```

**Attendu :** la tâche `Déployer le fichier témoin` passe en `changed`, et le fichier retrouve son contenu d'origine.

## 2. Provisionner (OpenTofu)

`scripts/deploy.sh` enchaîne la séquence demandée. La voici à la main, pour la première version :

```bash
VERSION=$(git rev-parse --short=7 HEAD)
scripts/build.sh "$VERSION"                 # image construite sur la VM

cd infra
tofu init -backend-config="path=$HOME/.websolutions/test/infra.tfstate"
tofu fmt -check
tofu validate
tofu plan -var "api_version=$VERSION" -out=infra.tfplan
tofu show infra.tfplan
tofu apply infra.tfplan
tofu output
tofu plan -var "api_version=$VERSION"       # doit afficher : No changes.
```

**Attendu :**

- premier plan : `Plan: 6 to add` (réseau, volume, 2 images, 2 conteneurs) ;
- `tofu apply` attend que PostgreSQL **et** l'API soient `healthy` (`wait = true`) : un conteneur qui ne démarre pas fait échouer l'apply ;
- `tofu output` :

```
api_upstream   = "http://127.0.0.1:3000"
db_volume      = "websolutions-test-pgdata"
deployed_image = "websolutions-api:<version>"
health_url     = "http://192.168.56.20/health"
web_url        = "http://192.168.56.20/"
```

- second plan : `No changes. Your infrastructure matches the configuration.`

Changement attendu entre deux versions : seuls `docker_image.api` et `docker_container.api` sont remplacés. Le réseau, la base et son volume ne bougent pas.

Vérification :

```bash
curl -s http://192.168.56.20/health        # {"status":"ok","version":"<version>","database":"ok"}
curl -s http://192.168.56.20/api/projects  # 2 projets lus dans PostgreSQL
ssh vboxuser@192.168.56.20 docker ps --filter name=websolutions
```

## 3. Livrer (pipeline)

### Le pipeline

Fichier : [`.github/workflows/tp02-websolutions.yml`](../../.github/workflows/tp02-websolutions.yml) (à la racine du dépôt, c'est là que GitHub le cherche).

| Job | Dépend de | Ce qu'il fait |
|-----|-----------|---------------|
| `test` | – | `scripts/test.sh` : build de l'étape `test` du Dockerfile, qui lance `npm test` |
| `build` | `test` | version = SHA court du commit, `scripts/build.sh` construit `websolutions-api:<sha>` sur la VM |
| `deploy` | `build` | `scripts/deploy.sh <sha>` (fmt, validate, plan, apply), puis `scripts/healthcheck.sh <sha>` |

Le contrôle de santé passe par Nginx (`http://192.168.56.20/health`). Il vérifie `status = ok` **et** que la version servie est bien celle qui vient d'être déployée.

Le même enchaînement peut tourner sans GitHub :

```bash
TF_VAR_db_password=... scripts/pipeline.sh
```

### Mise en place du runner (une fois)

Le runner doit joindre la VM. Comme elle n'est visible que depuis le Mac, c'est un runner **auto-hébergé sur le Mac** :

1. GitHub > dépôt > Settings > Actions > Runners > New self-hosted runner (macOS), puis suivre les commandes affichées (`./config.sh …`).
2. Lancer `./run.sh` depuis un terminal, pour qu'il hérite du `PATH` (tofu, docker, jq) et de l'agent SSH.
3. Settings > Environments > `test` > secret `WEBSOLUTIONS_DB_PASSWORD`.

Sécurité : le dépôt est public. Le workflow ne se déclenche donc que sur `push` vers `main` et en manuel, jamais sur `pull_request`. Le code d'un fork ne peut pas s'exécuter sur le Mac.

### Démonstration : un test en échec bloque le déploiement

Dans `app/test/app.test.js`, changer `assert.equal(result.status, 200);` en `assert.equal(result.status, 201);` puis pousser.

**Attendu :** job `test` en rouge (`✖ GET /health renvoie 200 quand la base répond`), jobs `build` et `deploy` **skipped**. La version en place sur la VM ne change pas : `curl http://192.168.56.20/health` renvoie toujours l'ancien SHA.

On remet le test, on pousse : les trois jobs passent au vert, et le contrôle de santé affiche `Santé OK : version <nouveau sha> servie sur http://192.168.56.20/health`.

### Version déployée et retour arrière

- Version en place : `tofu -chdir=infra output deployed_image`, ou le champ `version` de `/health`.
- Versions disponibles sur la VM (gardées grâce à `keep_locally = true`) :

```bash
DOCKER_HOST=ssh://vboxuser@192.168.56.20 docker image ls websolutions-api
```

- Revenir à la version précédente :

```bash
scripts/deploy.sh <sha_precedent>
scripts/healthcheck.sh <sha_precedent>
```

Seul le conteneur de l'API est remplacé. Les données restent dans le volume.

## 4. Résultats obtenus

| Vérification | Commande | Résultat |
|--------------|----------|----------|
| Tests unitaires | `npm test` (dans `app/`) | 4/4 passés |
| Étape test du Dockerfile | `scripts/test.sh` | `Tests OK` |
| Image livrée | `docker build app/` | construite (`node:24-alpine`, utilisateur `node`) |
| Syntaxe IaC | `tofu fmt -check` + `tofu validate` | `Success! The configuration is valid.` |
| Syntaxe Ansible | `ansible-playbook playbook.yml --syntax-check` | `playbook: playbook.yml` |
| Configuration ×2, dérive | section 1 | **à consigner** (VM éteinte au moment de la rédaction) |
| Plan / apply / plan sans changement | section 2 | **à consigner** |
| Pipeline en échec puis en succès | section 3 | **à consigner** (captures des jobs GitHub) |

## 5. Arrêter proprement

Les données utiles sont dans le volume `websolutions-test-pgdata`. On les sauvegarde avant de détruire quoi que ce soit :

```bash
ssh vboxuser@192.168.56.20 \
  'docker exec websolutions-test-db pg_dump -U websolutions websolutions' > backup.sql   # ne pas versionner
```

Ensuite, on vérifie que le plan de destruction vise bien l'environnement `test`, et rien d'autre :

```bash
cd infra
tofu plan -destroy -var "api_version=$(tofu output -raw deployed_image | cut -d: -f2)" -out=destroy.tfplan
tofu show destroy.tfplan        # uniquement des ressources websolutions-test-*
tofu apply destroy.tfplan
rm -f destroy.tfplan
```

Pour libérer la VM : supprimer les anciennes images (`docker image prune` sur la VM). Ansible ne défait pas sa configuration ; à remettre à la main si besoin (`ufw disable`, site Nginx).

## 6. Analyse

**Décisions**

- **VM VirtualBox existante comme cible.** Pas de facturation, et elle est déjà prête depuis les ateliers.
- **OpenTofu pilote Docker en `ssh://`.** Aucun port Docker exposé sur le réseau, juste SSH, déjà ouvert.
- **Image construite directement sur la VM**, taguée avec le SHA du commit. Pas besoin de registre, et la version déployée correspond toujours à un commit précis.
- **Tests dans une étape du Dockerfile.** Le runner n'a pas besoin de Node, et les tests tournent dans le même environnement que l'image livrée.
- **`wait = true` et healthchecks côté OpenTofu**, en plus du contrôle HTTP du pipeline : un conteneur cassé fait échouer l'apply tout de suite.
- **État OpenTofu local, hors dépôt**, partagé entre les lancements manuels et le runner, qui tournent avec le même compte.

**Difficultés prévisibles**

- Le runner lancé en service (launchd) n'a pas le même `PATH` que le terminal. D'où le lancement par `./run.sh` dans un terminal.
- Après l'ajout au groupe `docker`, il faut une nouvelle session SSH : le playbook fait un `reset_connection`.
- Docker contourne ufw pour les ports publiés. C'est pour ça que l'API n'est publiée que sur `127.0.0.1`.
- Si Nginx des ateliers B3/B4 tourne encore avec le site par défaut, le playbook le désactive.

**Limites du scénario local**

- La VM est créée à la main (atelier A2). Elle n'est pas décrite en IaC, car les fournisseurs VirtualBox sont peu fiables sur Mac Apple Silicon.
- L'état est local, sans verrouillage partagé : une seule personne peut déployer à la fois.
- Le runner dépend du Mac allumé et de la VM démarrée.
- Pas de HTTPS, une seule instance de l'API, pas de sauvegarde automatique de la base.

**Pour la production**

- Créer les VM ou instances avec OpenTofu chez un fournisseur cloud ou sur un hyperviseur avec un fournisseur maintenu.
- Ranger l'état dans un backend distant avec verrouillage (S3 + DynamoDB, ou équivalent).
- Pousser les images dans un registre privé, les signer et les scanner (Trivy).
- Gérer les secrets avec un vrai gestionnaire (Vault, secrets du cloud) plutôt qu'en variables d'environnement.
- Mettre une base managée ou répliquée avec des sauvegardes planifiées, faire du HTTPS avec Let's Encrypt et lancer plusieurs instances de l'API derrière Nginx.
- Ajouter une validation manuelle avant la production (environnement `production` protégé dans GitHub).
