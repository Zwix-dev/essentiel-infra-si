# Atelier A5 · Déployer avec Minikube

## Objectif

Démarrer un cluster Kubernetes local avec Minikube (profil `infra-si`), déployer Nginx, l'exposer, puis observer le remplacement d'un Pod par le Deployment.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`nginx.yaml`](nginx.yaml) | Manifeste du Deployment `nginx` (1 réplique, `nginx:1.28-alpine`) et du Service `ClusterIP` sur le port 80 |

L'atelier a été réalisé avec les commandes impératives de l'énoncé (`create deployment` puis `expose`). Le manifeste `nginx.yaml` décrit le même état de façon déclarative et permet de rejouer l'atelier en une commande :

```bash
minikube -p infra-si kubectl -- apply -f nginx.yaml
minikube -p infra-si kubectl -- rollout status deployment/nginx --timeout=120s
```

## Prérequis

- Docker Desktop démarré (conteneurs Linux)
- Minikube (`v1.39.0` utilisé), pilote `docker`
- `kubectl` non nécessaire : les commandes passent par `minikube kubectl --`
- Port `8090` libre sur l'hôte pour le `port-forward`

## 1. Démarrer le cluster

```bash
minikube start -p infra-si --driver=docker
minikube -p infra-si kubectl -- get nodes
```

```
😄  [infra-si] minikube v1.39.0 on Darwin 26.6.2 (arm64)
✨  Using the docker driver based on user configuration
📌  Using Docker Desktop driver with root privileges
👍  Starting "infra-si" primary control-plane node in "infra-si" cluster
🔥  Creating docker container (CPUs=2, Memory=6100MB) ...
📦  Preparing Kubernetes v1.37.0 on containerd 2.3.4 ...
🔗  Configuring CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "infra-si" cluster and "default" namespace by default

NAME       STATUS     ROLES           AGE   VERSION
infra-si   NotReady   control-plane   6s    v1.37.0
```

Le nœud est `NotReady` juste après le démarrage : le cluster finit encore de s'initialiser (CNI), il passe `Ready` quelques secondes plus tard.

## 2. Déployer et exposer Nginx

```bash
minikube -p infra-si kubectl -- create deployment nginx --image=nginx:1.28-alpine
minikube -p infra-si kubectl -- rollout status deployment/nginx --timeout=120s
minikube -p infra-si kubectl -- expose deployment nginx --port=80
minikube -p infra-si kubectl -- get pods,services
```

```
deployment.apps/nginx created
Waiting for deployment "nginx" rollout to finish: 0 of 1 updated replicas are available...
deployment "nginx" successfully rolled out
service/nginx exposed

NAME                         READY   STATUS    RESTARTS   AGE
pod/nginx-8487486ff9-r2cr4   1/1     Running   0          15s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   25s
service/nginx        ClusterIP   10.101.174.17   <none>        80/TCP    0s
```

**Attendu :** Pod `1/1 Running`, Service `nginx` présent.

Le Service `nginx` est de type `ClusterIP` : il n'est joignable que dans le cluster, d'où le `port-forward` ci-dessous.

## 3. Test depuis le Mac

```bash
minikube -p infra-si kubectl -- port-forward service/nginx 8090:80
```

```
Forwarding from 127.0.0.1:8090 -> 80
Forwarding from [::1]:8090 -> 80
Handling connection for 8090
```

**Résultat :** la page « Welcome to nginx! » s'affiche dans le navigateur sur `http://127.0.0.1:8090` (`Handling connection for 8090` confirme la requête).

## 4. Remplacement d'un Pod

Arrêt du port-forward avec `Ctrl+C`, puis :

```bash
minikube -p infra-si kubectl -- get pods
minikube -p infra-si kubectl -- delete pod nginx-8487486ff9-r2cr4
minikube -p infra-si kubectl -- get pods
```

```
NAME                     READY   STATUS    RESTARTS   AGE
nginx-8487486ff9-r2cr4   1/1     Running   0          3m13s

pod "nginx-8487486ff9-r2cr4" deleted from default namespace

NAME                     READY   STATUS    RESTARTS   AGE
nginx-8487486ff9-l2gdj   1/1     Running   0          10s
```

Le Pod supprimé (`r2cr4`) est remplacé par un nouveau Pod (`l2gdj`) : le Deployment maintient le nombre de répliques demandé (1).

Deuxième essai :

```
pod "nginx-8487486ff9-l2gdj" deleted from default namespace

NAME                     READY   STATUS    RESTARTS   AGE
nginx-8487486ff9-r7xfx   1/1     Running   0          2s
```

Nouveau remplacement (`l2gdj` → `r7xfx`) : le comportement est identique à chaque suppression.

## 5. Nettoyage

```bash
minikube delete -p infra-si
```

```
🔥  Deleting "infra-si" in docker ...
🔥  Deleting container "infra-si" ...
🔥  Removing ~/.minikube/machines/infra-si ...
💀  Removed all traces of the "infra-si" cluster.
```