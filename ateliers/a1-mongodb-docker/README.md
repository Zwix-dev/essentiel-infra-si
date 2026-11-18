# Atelier A1 · MongoDB avec Docker

## Objectif

Démarrer MongoDB avec Docker Compose, l'interroger dans son conteneur, puis vérifier que les données survivent au remplacement du conteneur grâce à un volume nommé.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`docker-compose.yml`](docker-compose.yml) | Service `mongo` (image `mongo:7`), port publié sur la boucle locale, volume nommé `mongo-data` |
| [`img.png`](img.png) | Capture du premier `docker compose up -d` |

## Prérequis

- Docker Desktop (macOS) démarré, moteur de conteneurs Linux
- Docker Compose v2

```bash
docker version
docker compose version
```

## Configuration

```yaml
services:
  mongo:
    image: mongo:7
    restart: unless-stopped
    ports:
      - "127.0.0.1:27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: example
    volumes:
      - mongo-data:/data/db
volumes:
  mongo-data:
```

- Port publié **uniquement** sur `127.0.0.1` : MongoDB n'est pas exposé sur le réseau.
- Volume nommé `mongo-data` monté sur `/data/db` : les données vivent hors du conteneur.
- Identifiants `root` / `example` : valeurs fictives propres à l'exercice. Les variables `MONGO_INITDB_*` ne créent le compte qu'au premier démarrage sur un volume vierge.

## 1. Démarrer le service

Depuis ce dossier :

```bash
docker compose config --quiet
docker compose up -d
docker compose ps
```

![docker compose up -d](img.png)

```
[+] up 14/14
 ✔ Image mongo:7                       Pulled
 ✔ Network a1-mongodb-docker_default   Created
 ✔ Volume a1-mongodb-docker_mongo-data Created
 ✔ Container a1-mongodb-docker-mongo-1 Started
```

```
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS                        NAMES
0f2beeef8f55   mongo:7   "docker-entrypoint.s…"   19 seconds ago   Up 18 seconds   127.0.0.1:27017->27017/tcp   a1-mongodb-docker-mongo-1
```

**Attendu :** conteneur `Up`, port `127.0.0.1:27017->27017/tcp`.

## 2. Créer et lire un document

```bash
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin
```

Dans le shell MongoDB :

```javascript
use support
db.tickets.updateOne(
  { code: "T-101" },
  { $set: { sujet: "Acces au portail" } },
  { upsert: true }
)
db.tickets.findOne({ code: "T-101" })
exit
```

Résultat obtenu :

```
{
  acknowledged: true,
  insertedId: ObjectId('6afd60adaa1c30b749d3ca46'),
  matchedCount: 0,
  modifiedCount: 0,
  upsertedCount: 1
}
{
  _id: ObjectId('6afd60adaa1c30b749d3ca46'),
  code: 'T-101',
  sujet: 'Acces au portail'
}
```

**Attendu :** `upsertedCount: 1`, puis le document `T-101` est lu.

Chaîne de connexion depuis un client sur l'hôte : `mongodb://root:example@127.0.0.1:27017/support?authSource=admin`. Depuis un autre service du même projet Compose, remplacer `127.0.0.1` par `mongo`.

## 3. Vérifier la persistance

Le conteneur et le réseau sont supprimés, le volume est conservé :

```bash
docker compose down
docker compose up -d
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin
```

```
[+] down 2/2
 ✔ Container a1-mongodb-docker-mongo-1 Removed
 ✔ Network a1-mongodb-docker_default   Removed

[+] up 2/2
 ✔ Network a1-mongodb-docker_default   Created
 ✔ Container a1-mongodb-docker-mongo-1 Started
```

```
test> use support
switched to db support
support> db.tickets.findOne({ code: "T-101" })
{
  _id: ObjectId('6afd60adaa1c30b749d3ca46'),
  code: 'T-101',
  sujet: 'Acces au portail'
}
```

**Résultat :** le document `T-101` est retrouvé avec le même `_id` dans un **nouveau** conteneur. Les données sont dans le volume `a1-mongodb-docker_mongo-data`, pas dans le conteneur.

## 4. Nettoyage

```bash
docker compose down
```

Le volume est conservé. Pour une remise à zéro volontaire (suppression des données) :

```bash
docker compose down -v
docker volume ls --filter name=mongo-data
```
