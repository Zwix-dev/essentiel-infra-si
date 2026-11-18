# Atelier B1 · Déployer Nginx avec OpenTofu

## Objectif

Déployer un conteneur Nginx avec OpenTofu et le fournisseur Docker : examiner un plan, l'appliquer, lire l'état, puis retirer les ressources.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`tofu-nginx/main.tf`](tofu-nginx/main.tf) | Fournisseur Docker, image `nginx:1.28-alpine`, conteneur `infra-si-nginx`, sortie `nginx_url` |
| [`tofu-nginx/.terraform.lock.hcl`](tofu-nginx/.terraform.lock.hcl) | Version et empreintes du fournisseur `kreuzwerker/docker` 3.7.0 |

Non versionnés (voir `.gitignore` racine) : `.terraform/`, `terraform.tfstate*`, `*.tfplan`. Ces fichiers sont régénérés par les commandes ci-dessous. Aucune variable n'est nécessaire, donc pas de `terraform.tfvars.example`.

## Prérequis

- macOS (arm64), Docker Desktop démarré
- OpenTofu `v1.13.9` (`darwin_arm64`), installé avec `brew install opentofu`
- Port `8081` libre sur l'hôte

```bash
tofu version
docker version
cd tofu-nginx
```

## 1. Configuration (`main.tf`)

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

resource "docker_image" "nginx" {
  name         = "nginx:1.28-alpine"
  keep_locally = true
}

resource "docker_container" "nginx" {
  name  = "infra-si-nginx"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = 8081
    ip       = "127.0.0.1"
  }
}

output "nginx_url" {
  value = "http://127.0.0.1:8081"
}
```

Trois écarts par rapport à l'énoncé, détaillés plus bas :
- version du fournisseur `3.7.0` au lieu de `3.6.1` ;
- bloc `output` placé **hors** de la ressource `docker_container` ;
- port externe `8081` au lieu de `8080`.

## 2. Initialisation

### Erreur avec la version 3.6.1

```bash
tofu init
```

```
Error: Failed to install provider

Error while installing kreuzwerker/docker v3.6.1: the provider is not signed with a valid
signing key; please contact the provider author (authentication signature from unknown issuer)
```

L'installation de la version `3.6.1` est refusée à cause de sa signature. Les notes de version du fournisseur indiquent que son ancienne clé de signature a expiré et que les versions à partir de la `3.7.0` sont signées avec une nouvelle clé.

### Correction : version 3.7.0

Version modifiée dans `main.tf`, puis :

```bash
tofu init
```

```
- Finding kreuzwerker/docker versions matching "3.7.0"...
- Installing kreuzwerker/docker v3.7.0...
- Installed kreuzwerker/docker v3.7.0 (signed, key ID 0DCE698927DAF8EC)

OpenTofu has created a lock file .terraform.lock.hcl to record the provider
selections it made above.

OpenTofu has been successfully initialized!
```

`brew upgrade opentofu` indique que la version `1.13.9` est déjà installée.

## 3. Validation

```bash
tofu fmt
tofu validate
```

Première tentative :

```
Error: Unsupported block type

  on main.tf line 22, in resource "docker_container" "nginx":
  22:   output "nginx_url" {

Blocks of type "output" are not expected here.
```

Le bloc `output` de l'énoncé était à l'intérieur de la ressource. Après l'avoir déplacé en dehors de l'accolade fermante de `docker_container` :

```
Success! The configuration is valid.
```

## 4. Plan et application

```bash
tofu plan -out=nginx.tfplan
tofu show nginx.tfplan
```

```
  # docker_container.nginx will be created
  + resource "docker_container" "nginx" {
      + name         = "infra-si-nginx"
      + network_mode = "bridge"
      + restart      = "no"
      + start        = true
      [...]
      + ports {
          + external = 8080
          + internal = 80
          + ip       = "127.0.0.1"
          + protocol = "tcp"
        }
    }

  # docker_image.nginx will be created
  + resource "docker_image" "nginx" {
      + keep_locally = true
      + name         = "nginx:1.28-alpine"
      [...]
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + nginx_url = "http://127.0.0.1:8080"
```

### Échec : port 8080 déjà utilisé

```bash
tofu apply nginx.tfplan
```

```
docker_image.nginx: Creating...
docker_image.nginx: Creation complete after 3s [id=sha256:a8b39bd9cf0f...nginx:1.28-alpine]
docker_container.nginx: Creating...

Error: Unable to start container: Error response from daemon: ports are not available:
exposing port TCP 127.0.0.1:8080 -> 127.0.0.1:0: listen tcp4 127.0.0.1:8080: bind: address already in use
```

L'image a été créée, mais le conteneur n'a pas pu démarrer : le port 8080 de la machine est déjà occupé.

Un nouvel `apply` du même plan est refusé :

```
Error: Saved plan is stale

The given plan file can no longer be applied because the state was changed by another
operation after the plan was created.
```

Le plan enregistré n'est plus valable, car l'état a changé après l'échec. Un nouveau plan (1 à créer : le conteneur) donne la même erreur au `apply`, puisque le port est toujours `8080`.

### Correction : port 8081

Port externe et sortie passés à `8081` dans `main.tf`, puis nouveau plan :

```bash
tofu plan -out=nginx.tfplan
```

```
      + ports {
          + external = 8081
          + internal = 80
          + ip       = "127.0.0.1"
          + protocol = "tcp"
        }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  ~ nginx_url = "http://127.0.0.1:8080" -> "http://127.0.0.1:8081"
```

```bash
tofu apply nginx.tfplan
```

```
docker_container.nginx: Creating...
docker_container.nginx: Creation complete after 0s [id=199f92181a82...]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

nginx_url = "http://127.0.0.1:8081"
```

Le conteneur `infra-si-nginx` est créé et publié sur `127.0.0.1:8081`.

## 5. Vérifications

Test de la page depuis le Mac :

```bash
curl http://127.0.0.1:8081
```

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
[...]
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
[...]
<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

La page d'accueil de Nginx répond sur `http://127.0.0.1:8081` : le conteneur est bien joignable depuis l'hôte.

Autres vérifications de l'énoncé :

```bash
tofu output nginx_url
docker ps --filter name=infra-si-nginx
tofu state list
tofu plan
```

**Attendu :**

- `tofu output nginx_url` : `"http://127.0.0.1:8081"` ;
- `docker ps` : conteneur `infra-si-nginx` `Up`, port `127.0.0.1:8081->80/tcp` ;
- `tofu state list` : `docker_container.nginx` et `docker_image.nginx` ;
- `tofu plan` : `No changes. Your infrastructure matches the configuration.` (idempotence).

**Statut :** la sortie `nginx_url` et l'accès HTTP sont validés ci-dessus. Les sorties de `docker ps`, `tofu state list` et du plan sans changement n'ont pas été consignées : étape à rejouer et à ajouter ici.

## 6. Nettoyage

```bash
tofu plan -destroy -out=nginx-destroy.tfplan
tofu show nginx-destroy.tfplan
```

```
  # docker_container.nginx will be destroyed
  - resource "docker_container" "nginx" {
      - name = "infra-si-nginx" -> null
      [...]
      - ports {
          - external = 8081 -> null
          - internal = 80 -> null
          - ip       = "127.0.0.1" -> null
          - protocol = "tcp" -> null
        }
    }

  # docker_image.nginx will be destroyed
  - resource "docker_image" "nginx" {
      - keep_locally = true -> null
      - name         = "nginx:1.28-alpine" -> null
      [...]
    }

Plan: 0 to add, 0 to change, 2 to destroy.

Changes to Outputs:
  - nginx_url = "http://127.0.0.1:8081" -> null
```

```bash
tofu apply nginx-destroy.tfplan
```

```
docker_container.nginx: Destroying... [id=199f92181a82...]
docker_container.nginx: Destruction complete after 0s
docker_image.nginx: Destroying... [id=sha256:a8b39bd9cf0f...nginx:1.28-alpine]
docker_image.nginx: Destruction complete after 0s

Apply complete! Resources: 0 added, 0 changed, 2 destroyed.
```

Vérification :

```bash
docker ps -a --filter name=infra-si-nginx
```

```
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Aucun conteneur ne correspond : `infra-si-nginx` a bien disparu.

## 7. Résumé des problèmes rencontrés

| Problème | Cause | Solution |
|----------|-------|----------|
| `tofu init` : provider non signé | Clé de signature de la version 3.6.1 expirée | Passage à la version 3.7.0 |
| `tofu validate` : `Unsupported block type` | Bloc `output` dans la ressource `docker_container` | Bloc déplacé en dehors de la ressource |
| `apply` : `address already in use` | Port 8080 déjà occupé sur le Mac | Port externe et sortie passés à 8081 |
| `apply` : `Saved plan is stale` | État modifié après l'échec précédent | Nouveau `tofu plan -out` |