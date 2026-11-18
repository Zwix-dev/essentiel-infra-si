# Atelier B2 · Catalogue Node.js, PostgreSQL et Redis

## Objectif

Déployer avec OpenTofu une API Node.js qui utilise PostgreSQL et Redis, vérifier les dépendances entre services et distinguer la vie des conteneurs de celle des volumes.

## Architecture

| Ressource | Nom | Rôle |
|-----------|-----|------|
| Réseau | `infra-si-catalogue-net` | Réseau Docker dédié, les alias `db` et `redis` y sont résolus |
| Volume | `infra-si-catalogue-pg` | Données PostgreSQL |
| Volume | `infra-si-catalogue-redis` | Données Redis |
| Conteneur | `infra-si-catalogue-db` | PostgreSQL 16 (alias `db`, port 5432 interne) |
| Conteneur | `infra-si-catalogue-cache` | Redis 7 (alias `redis`, port 6379 interne) |
| Conteneur | `infra-si-catalogue-api` | API Node.js, publiée sur `127.0.0.1:3000` |

Les ports de la base et du cache restent internes au réseau Docker ; seule l'API est exposée sur l'hôte.

## Prérequis

- macOS (arm64), Docker Desktop démarré
- OpenTofu `v1.13.9`, fournisseur `kreuzwerker/docker` `3.7.0` (version `3.6.1` refusée, voir [B1](../b1-nginx-opentofu/))
- Port `3000` libre sur l'hôte

Toutes les commandes se lancent depuis `tofu-catalogue/`.

## Fichiers versionnés

| Fichier | Rôle |
|---------|------|
| [`tofu-catalogue/versions.tf`](tofu-catalogue/versions.tf) | Fournisseur Docker |
| [`tofu-catalogue/variables.tf`](tofu-catalogue/variables.tf) | Variables (`db_password` marquée `sensitive`) |
| [`tofu-catalogue/main.tf`](tofu-catalogue/main.tf) | Réseau, volumes, images, conteneurs et sortie `api_url` |
| [`tofu-catalogue/terraform.tfvars.example`](tofu-catalogue/terraform.tfvars.example) | Modèle de variables à copier en `terraform.tfvars` |
| [`tofu-catalogue/.terraform.lock.hcl`](tofu-catalogue/.terraform.lock.hcl) | Versions du fournisseur |
| [`tofu-catalogue/api/`](tofu-catalogue/api/) | `Dockerfile`, `package.json`, `server.js` de l'API |

Non versionnés : `terraform.tfvars` (mot de passe), `terraform.tfstate*` (contient le mot de passe en clair), `*.tfplan`, `.terraform/`.

## 1. Arborescence

```
tofu-catalogue/
├── versions.tf
├── variables.tf
├── main.tf
├── terraform.tfvars.example   (versionné)
├── terraform.tfvars           (local, ignoré)
└── api/
    ├── Dockerfile
    ├── package.json
    └── server.js
```

### `api/package.json`

```json
{
  "name": "infra-si-catalogue",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "pg": "8.16.3",
    "redis": "4.7.0"
  }
}
```

### `api/Dockerfile`

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY server.js .
USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

### `api/server.js`

Le service expose deux routes :
- `GET /health` : interroge PostgreSQL (`SELECT 1`) et Redis (`PING`) ;
- `GET /products` : lit la clé `products:v1` dans Redis ; en cas d'absence, lit la table `products` dans PostgreSQL et met le résultat en cache pendant 30 secondes. La réponse indique la `source` (`redis` ou `postgresql`).

Au démarrage, l'API crée la table `products` si besoin et y insère deux produits (`Clavier`, `Souris`).

### `versions.tf`

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.7.0"
    }
  }
}

provider "docker" {}
```

### `variables.tf`

```hcl
variable "api_port" {
  type    = number
  default = 3000
}

variable "api_image_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "catalogue"
}

variable "db_user" {
  type    = string
  default = "catalogue"
}

variable "db_password" {
  type      = string
  sensitive = true
}
```

### `main.tf`

- `docker_network.catalogue`, `docker_volume.postgres`, `docker_volume.redis`
- `docker_image.postgres` (`postgres:16-alpine`) et `docker_image.redis` (`redis:7-alpine`), avec `keep_locally = true`
- `docker_container.postgres` : variables d'environnement `POSTGRES_*`, alias `db`, volume monté sur `/var/lib/postgresql/data`, healthcheck `pg_isready`, `wait = true`
- `docker_container.redis` : `redis-server --appendonly yes`, alias `redis`, volume monté sur `/data`, healthcheck `redis-cli ping`, `wait = true`
- `docker_container.api` : image construite localement, variables `DB_*` et `REDIS_URL`, port `127.0.0.1:3000`, `depends_on` sur PostgreSQL et Redis
- sortie `api_url`

Les healthchecks et `wait = true` font attendre le fournisseur jusqu'à ce que PostgreSQL et Redis soient prêts avant de créer l'API.

## 2. Construction de l'image de l'API

```bash
docker build -t infra-si-catalogue-api:lab ./api
docker image inspect --format "{{.Id}}" infra-si-catalogue-api:lab
```

```
 => [1/5] FROM docker.io/library/node:24-bookworm-slim@sha256:dc26ae92c9fb...
 => [2/5] WORKDIR /app
 => [3/5] COPY package.json .
 => [4/5] RUN npm install --omit=dev
 => [5/5] COPY server.js .
 => exporting to image
 => => naming to docker.io/library/infra-si-catalogue-api:lab
```

```
sha256:c670bce0869d7b2ef351b1d972a14a4c6b90ec6ef3191d22fb35815a48bed595
```

### `terraform.tfvars`

Créé à partir du modèle versionné :

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
api_image_id = "sha256:REMPLACER_PAR_IDENTIFIANT_COMPLET"
db_password  = "REMPLACER_PAR_UN_MOT_DE_PASSE_LOCAL"
```

`api_image_id` reçoit l'identifiant affiché par `docker image inspect` ci-dessus. `db_password` reçoit un mot de passe propre au laboratoire. La valeur sensible reste présente en clair dans l'état local : `terraform.tfvars`, le `.tfstate` et les plans ne sont pas versionnés.

## 3. Initialisation et validation

```bash
tofu init
tofu fmt
tofu validate
```

```
- Finding kreuzwerker/docker versions matching "3.7.0"...
- Installing kreuzwerker/docker v3.7.0...
- Installed kreuzwerker/docker v3.7.0 (signed, key ID 0DCE698927DAF8EC)

OpenTofu has been successfully initialized!
```

```
Success! The configuration is valid.
```

## 4. Plan et application

```bash
tofu plan -out=catalogue.tfplan
tofu show catalogue.tfplan
```

```
  # docker_container.api will be created
  # docker_container.postgres will be created
  # docker_container.redis will be created
  # docker_image.postgres will be created
  # docker_image.redis will be created
  # docker_network.catalogue will be created
  # docker_volume.postgres will be created
  # docker_volume.redis will be created

Plan: 8 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + api_url = "http://127.0.0.1:3000"
```

Les variables d'environnement des conteneurs sont affichées `(sensitive value)` : le mot de passe n'apparaît pas dans le plan.

Ports du conteneur `api` dans le plan :

```
      + ports {
          + external = 3000
          + internal = 3000
          + ip       = "127.0.0.1"
          + protocol = "tcp"
        }
```

### Application : réseau, volumes, base et cache

```bash
tofu apply catalogue.tfplan
```

```
docker_network.catalogue: Creation complete after 2s [id=9d1bead17ee5...]
docker_volume.redis: Creation complete after 0s [id=infra-si-catalogue-redis]
docker_volume.postgres: Creation complete after 0s [id=infra-si-catalogue-pg]
docker_image.redis: Creation complete after 3s [id=sha256:7f7d30b7fdd0...redis:7-alpine]
docker_container.redis: Creation complete after 4s [id=c070f825d90d...]
docker_image.postgres: Creation complete after 5s [id=sha256:81e77a483348...postgres:16-alpine]
docker_container.postgres: Creation complete after 4s [id=9ddbe78dfdcc...]
```

Redis et PostgreSQL sont créés et prêts (healthchecks validés) avant l'API.

### Application : API

Après avoir renseigné l'identifiant de l'image dans `terraform.tfvars` :

```bash
tofu plan -out=catalogue.tfplan
tofu apply catalogue.tfplan
tofu output api_url
```

```
Plan: 1 to add, 0 to change, 0 to destroy.
```

```
docker_container.api: Creating...
docker_container.api: Creation complete after 0s [id=cea27f91e22d...]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

api_url = "http://127.0.0.1:3000"
```

```
"http://127.0.0.1:3000"
```

## 5. Vérification de l'API et du cache

```bash
curl http://127.0.0.1:3000
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/products
```

```
{"error":"route introuvable"}
{"database":"ok","redis":"ok"}
{"source":"postgresql","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"}]}
```

- La racine `/` n'est pas une route de l'API : elle renvoie bien l'erreur `route introuvable`.
- `/health` : la base et le cache répondent (`database` et `redis` à `ok`).
- Premier appel à `/products` : les produits viennent de **PostgreSQL**.

Appels suivants, en moins de 30 secondes :

```bash
curl -fsS http://127.0.0.1:3000/health
curl -fsS http://127.0.0.1:3000/products
curl -fsS http://127.0.0.1:3000/products
```

```
{"database":"ok","redis":"ok"}
{"source":"redis","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"}]}
{"source":"redis","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"}]}
```

Les mêmes produits sont maintenant renvoyés depuis **Redis** : le cache fonctionne.

## 6. Persistance des données

```bash
docker exec infra-si-catalogue-db psql -U catalogue -d catalogue -c "INSERT INTO products VALUES (3, 'Ecran') ON CONFLICT DO NOTHING;"
docker restart infra-si-catalogue-db
```

Vérification après expiration du cache (plus de 30 secondes) :

```bash
curl -fsS http://127.0.0.1:3000/products
```

**Attendu :** `source` à `postgresql` et trois produits, dont `{"id":3,"name":"Ecran"}`.

**Statut :** l'insertion et le redémarrage ont été exécutés. La sortie de la relecture n'a pas été consignée : étape à rejouer et à ajouter ici.

Interprétation :
- Un **redémarrage** du conteneur PostgreSQL montre que les données survivent à l'arrêt du processus de la base.
- Le **remplacement** du conteneur en conservant le même volume montrerait en plus que les données sont stockées dans le **volume**, indépendamment du cycle de vie du conteneur.

## 7. Nettoyage

```bash
tofu plan -destroy -out=catalogue-destroy.tfplan
tofu show catalogue-destroy.tfplan
tofu apply catalogue-destroy.tfplan
docker ps -a --filter name=infra-si-catalogue
```

**Attendu :** `Plan: 0 to add, 0 to change, 8 to destroy.`, puis aucun conteneur `infra-si-catalogue-*` listé. Les volumes `infra-si-catalogue-pg` et `infra-si-catalogue-redis` sont gérés par OpenTofu et **supprimés** : sauvegarder les données à conserver avant. L'image `infra-si-catalogue-api:lab`, construite hors OpenTofu, reste disponible.

Pour supprimer aussi l'image de l'API et les plans locaux :

```bash
docker image rm infra-si-catalogue-api:lab
rm -f catalogue.tfplan catalogue-destroy.tfplan
```
