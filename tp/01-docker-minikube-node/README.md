# TP1 · Docker et Minikube avec Node.js

## Objectif

Faire tourner une petite application Node.js dans Docker, puis déployer exactement la même image dans Kubernetes avec Minikube, et comparer les deux.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`node-docker/server.js`](node-docker/server.js) | Serveur HTTP qui répond `Hello, Docker and Minikube from Node.js!` sur le port 3000 |
| [`node-docker/Dockerfile`](node-docker/Dockerfile) | Image basée sur `node:24-alpine`, lancée avec l'utilisateur `node` |
| [`node-docker/.dockerignore`](node-docker/.dockerignore) | N'envoie que `Dockerfile` et `server.js` au build |
| [`node-docker/deployment.yaml`](node-docker/deployment.yaml) | Deployment `hello-node` + Service `NodePort` (8080 → 3000, nodePort 30007) |

## Prérequis

- Docker Desktop lancé (conteneurs Linux)
- Minikube installé (`brew install minikube`), profil dédié `intro-docker`

```bash
docker version
minikube version
```

Toutes les commandes se lancent depuis `node-docker/`.

## 1. Dans Docker

```bash
docker build -t hello-node:1.0 .
docker run -d --name hello-node -p 127.0.0.1:8080:3000 hello-node:1.0
docker ps --filter name=hello-node
```

Au premier `docker run`, le port 8080 était déjà pris par un ancien conteneur. Je l'ai arrêté (`docker kill`), j'ai supprimé le conteneur `hello-node` resté en erreur (`docker rm hello-node`), puis j'ai relancé la commande. Ensuite, `http://127.0.0.1:8080` affiche bien :

```
Hello, Docker and Minikube from Node.js!
```

On supprime le conteneur de test. L'image, elle, reste disponible :

```bash
docker rm -f hello-node
```

## 2. Dans Minikube

```bash
minikube start -p intro-docker --driver=docker
minikube -p intro-docker image load hello-node:1.0
minikube -p intro-docker image ls
```

L'image apparaît dans le cluster sous le nom `docker.io/library/hello-node:1.0`. Comme le Deployment utilise `imagePullPolicy: IfNotPresent`, Kubernetes prend cette image locale au lieu d'essayer de la télécharger.

```bash
minikube -p intro-docker kubectl -- apply -f deployment.yaml
minikube -p intro-docker kubectl -- rollout status deployment/hello-node
minikube -p intro-docker kubectl -- get pods,services
```

```
NAME                              READY   STATUS    RESTARTS   AGE
pod/hello-node-7dd869979d-n7cbf   1/1     Running   0          3m55s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/hello-node   NodePort    10.109.178.6   <none>        8080:30007/TCP   3m55s
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP          6m35s
```

## 3. Accès au service

```bash
minikube -p intro-docker service hello-node --url
```

Avec le pilote Docker sur Mac, cette commande ouvre un tunnel. Il faut laisser le terminal ouvert et utiliser l'URL qu'elle affiche. Sinon, on peut passer par le transfert de port, puis aller sur `http://127.0.0.1:8080` :

```bash
minikube -p intro-docker kubectl -- port-forward service/hello-node 8080:8080
```

J'ai aussi vérifié depuis le Pod, en passant par le Service :

```bash
minikube -p intro-docker kubectl -- exec deploy/hello-node -- wget -qO- http://hello-node:8080
```

```
Hello, Docker and Minikube from Node.js!
```

On obtient le même message que dans Docker, ce qui est normal puisque c'est la même image.

## 4. Analyse

**1. Pourquoi Node.js n'a pas besoin d'être installé sur le poste ?**

Node.js est déjà dans l'image : elle part de `node:24-alpine`, qui contient Node. Le conteneur apporte donc son propre environnement d'exécution. Le poste a seulement besoin de Docker pour lancer l'image, et Minikube s'appuie lui aussi sur Docker.

**2. Qu'est-ce qui rend l'application accessible dans les deux cas ?**

- Dans **Docker**, c'est la publication de port `-p 127.0.0.1:8080:3000`. Le port 8080 du Mac est relié au port 3000 du conteneur.
- Dans **Kubernetes**, c'est le **Service** `hello-node`. Il trouve le Pod grâce au label `app: hello-node`, reçoit le trafic sur 8080 et l'envoie au port 3000 du Pod. Le NodePort 30007 l'ouvre sur le nœud. Depuis le Mac, on y accède par le tunnel `minikube service` ou par `port-forward`.

Dans les deux cas, l'appli écoute sur `0.0.0.0`, sinon elle ne serait pas joignable depuis l'extérieur du conteneur.

**3. Cycle de vie : conteneur Docker et Pod géré par un Deployment**

Un conteneur lancé avec `docker run` vit tout seul. S'il s'arrête ou s'il est supprimé, personne ne le recrée : c'est à nous de le relancer.

Avec Kubernetes, on décrit un état voulu, ici une réplique. Si le Pod plante ou est supprimé, le Deployment, via son ReplicaSet, en recrée automatiquement un nouveau, avec un autre nom. On l'a vu dans l'atelier [A5](../../ateliers/a5-nginx-minikube/). En plus, la `readinessProbe` fait que le Pod ne reçoit du trafic qu'une fois qu'il répond vraiment sur `/`.

**4. Relevés**

| Élément | Valeur |
|---------|--------|
| État du Pod | `1/1 Running` (Ready), 0 redémarrage |
| Port du Service | `8080` → `targetPort 3000`, NodePort `30007` (`8080:30007/TCP`) |
| Message HTTP | `Hello, Docker and Minikube from Node.js!` |

## 5. Nettoyage

On arrête le tunnel ou le `port-forward` avec `Ctrl+C`, puis :

```bash
minikube -p intro-docker kubectl -- delete -f deployment.yaml
minikube delete -p intro-docker
```

Si on veut aussi supprimer l'image : `docker image rm hello-node:1.0`.
