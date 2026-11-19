# TP3 · Plateforme DevSecOps locale avec OpenTofu

## Objectif

Héberger en local une forge (Gitea), une intégration continue (Jenkins) et un outil de qualité de code (SonarQube Community Build, adossé à PostgreSQL), le tout décrit et géré par OpenTofu avec le fournisseur Docker.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`versions.tf`](versions.tf) | Fournisseur `kreuzwerker/docker` épinglé, moteur Docker local |
| [`variables.tf`](variables.tf) | Mot de passe de la base `sonar` (sensible, sans valeur par défaut) et port publié de PostgreSQL |
| [`main.tf`](main.tf) | Réseau `devops-net`, 4 images, 6 volumes nommés, 4 conteneurs |
| [`outputs.tf`](outputs.tf) | URL d'accès et liste des volumes gérés |
| [`terraform.tfvars.example`](terraform.tfvars.example) | Modèle à copier en `terraform.tfvars` (ignoré par Git) |
| [`.terraform.lock.hcl`](.terraform.lock.hcl) | Verrou du fournisseur, versionné |

| Service | Image | Accès (boucle locale) | Stockage |
|---------|-------|-----------------------|----------|
| Gitea | `gitea/gitea:1.25` | http://localhost:3000 | volume `devops-gitea` sur `/data` (SQLite) |
| Jenkins | `jenkins/jenkins:lts-jdk21` | http://localhost:8080 | volume `devops-jenkins` sur `/var/jenkins_home` |
| SonarQube | `sonarqube:community` | http://localhost:9000 | volumes `devops-sonar`, `devops-plugins`, `devops-logs` |
| PostgreSQL | `postgres:16-alpine` | `127.0.0.1:5432` (5433 sur mon poste) et alias `postgres` dans le réseau | volume `devops-postgres` |

## Écarts par rapport à l'énoncé

- **Fournisseur en 3.7.0** au lieu de 3.6.1 : la 3.6.1 ne s'installe plus, sa clé de signature a expiré (même constat qu'en B1 et TP2).
- **Mot de passe en variable** : au lieu de `local.password` écrit dans `main.tf`, le mot de passe vient de `terraform.tfvars`, qui n'est pas versionné. Il finit quand même en clair dans l'état OpenTofu, d'où l'état gardé hors du dépôt.
- **Port PostgreSQL en variable** : un PostgreSQL tourne déjà sur mon Mac sur 5432, la pile publie donc sur 5433. Dans le réseau Docker, SonarQube joint toujours `postgres:5432`.

## Prérequis

- Docker Desktop (conteneurs Linux) avec environ 8 Go alloués au moteur. Sur mon poste : 10 CPU, 7,75 Go.
- OpenTofu ≥ 1.8 (testé avec 1.13.9).
- Ports 3000, 8080, 9000 libres. J'ai arrêté le conteneur `infra-si-catalogue-api` de l'atelier B2 qui occupait 3000 (`docker stop`, relançable avec `docker start`).
- Limites du noyau pour Elasticsearch, embarqué dans SonarQube :

```bash
docker run --rm alpine:3.22 cat /proc/sys/vm/max_map_count /proc/sys/fs/file-max
```

Docker Desktop renvoyait `262144` pour `vm.max_map_count`, sous les 524288 demandés (`fs.file-max` était largement suffisant). Je l'ai relevé dans la VM de Docker Desktop avec un conteneur privilégié. Ce réglage est perdu au redémarrage de Docker Desktop, il faut donc le refaire avant chaque démarrage de la pile :

```bash
docker run --rm --privileged alpine:3.22 sysctl -w vm.max_map_count=524288
```

## Démarrage

```bash
cp terraform.tfvars.example terraform.tfvars   # mettre un mot de passe (ex. openssl rand -hex 16)
tofu init
tofu fmt
tofu validate
tofu plan -out=devops.tfplan
tofu show devops.tfplan
tofu apply devops.tfplan
docker ps -a --filter name=devops-
```

Le plan annonce `Plan: 15 to add, 0 to change, 0 to destroy.` (1 réseau, 4 images, 6 volumes, 4 conteneurs).

```
NAMES             IMAGE          STATUS                    PORTS
devops-jenkins    74401de6a6f9   Up 19 seconds             127.0.0.1:8080->8080/tcp
devops-sonar      65541accbdb9   Up 19 seconds             127.0.0.1:9000->9000/tcp
devops-gitea      f846d26a4fc3   Up 19 seconds             127.0.0.1:3000->3000/tcp
devops-postgres   81e77a483348   Up 41 seconds (healthy)   127.0.0.1:5433->5432/tcp
```

PostgreSQL passe `healthy` avant que SonarQube ne démarre : OpenTofu attend le healthcheck (`wait = true`) et SonarQube dépend explicitement du conteneur PostgreSQL.

## Vérifications

**Les quatre interfaces répondent :**

```
http://localhost:3000        200   (Gitea)
http://localhost:8080/login  200   (Jenkins)
http://localhost:9000        200   (SonarQube)
```

**SonarQube est prêt** (`/api/system/status`) :

```json
{"id":"46AF5D23-AaHz3lktuGzDgAU9xt31","version":"26.11.0.134175","status":"UP"}
```

**SonarQube joint bien sa base**, extrait de `docker logs --tail 60 devops-sonar` :

```
INFO  ce[][o.s.d.DefaultDatabase] Create JDBC data source for jdbc:postgresql://postgres:5432/sonar
INFO  ce[][c.z.h.p.HikariPool] HikariPool-1 - Added connection org.postgresql.jdbc.PgConnection@4b4c0b75
INFO  app[][o.s.a.SchedulerImpl] SonarQube is operational
```

```bash
docker exec devops-postgres pg_isready -h 127.0.0.1 -U sonar -d sonar
```

```
127.0.0.1:5432 - accepting connections
```

**Le plan est stable** après l'application :

```
No changes. Your infrastructure matches the configuration.
```

**Gitea garde ses données après un redémarrage.** J'ai terminé l'installation en SQLite (formulaire de la page d'accueil, compte administrateur de laboratoire), créé un dépôt privé `depot-test`, puis redémarré le conteneur :

```bash
docker restart devops-gitea
curl -s -u labadmin:*** http://localhost:3000/api/v1/repos/labadmin/depot-test | jq -r .full_name
```

```
labadmin/depot-test
```

Le dépôt est toujours là parce qu'il vit dans le volume `devops-gitea`, pas dans le conteneur.

**Jenkins** : la page de déverrouillage s'affiche, le mot de passe d'amorçage existe bien dans le conteneur. Je ne le recopie pas ici.

```bash
docker exec devops-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

**SonarQube** accepte encore le compte d'amorçage `admin/admin`. Il faut le changer à la première connexion.

**Versions réellement récupérées** (les tags `lts-jdk21` et `community` bougent) :

| Image | Version | Digest |
|-------|---------|--------|
| `jenkins/jenkins:lts-jdk21` | Jenkins 2.580.2 | `sha256:74401de6a6f9…` |
| `sonarqube:community` | 26.11.0.134175 | `sha256:65541accbdb9…` |
| `gitea/gitea:1.25` | 1.25.5 | `sha256:f846d26a4fc3…` |
| `postgres:16-alpine` | 16 | `sha256:81e77a483348…` |

La disponibilité des quatre interfaces valide le déploiement des outils. Une vraie chaîne de build et d'analyse demanderait en plus un job Jenkins, un scanner et un jeton SonarQube : ce n'est pas l'objet de ce TP.

## Arrêt et nettoyage

Le plan de destruction supprime aussi les **volumes** : dépôts Gitea, configuration Jenkins et base SonarQube disparaissent. Sauvegarder d'abord ce qui doit être conservé, par exemple :

```bash
docker exec devops-postgres pg_dump -U sonar sonar > backup-sonar.sql   # ignoré par Git
docker exec -u git devops-gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip
```

```bash
tofu plan -destroy -out=devops-destroy.tfplan
tofu show devops-destroy.tfplan
tofu apply devops-destroy.tfplan
docker ps -a --filter name=devops-
```

```
Plan: 0 to add, 0 to change, 15 to destroy.
Apply complete! Resources: 0 added, 0 changed, 15 destroyed.
```

Ensuite, `docker ps -a --filter name=devops-` et `docker volume ls --filter name=devops-` ne renvoient plus rien. Les images restent en cache (`keep_locally = true`), ce qui rend le prochain démarrage rapide.

## Ce qui reste hors du dépôt

`terraform.tfvars`, `terraform.tfstate*`, `*.tfplan`, `.terraform/`, le mot de passe d'amorçage Jenkins, les mots de passe administrateur Gitea et SonarQube, et les sauvegardes.
