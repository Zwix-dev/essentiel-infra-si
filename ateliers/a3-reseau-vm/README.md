# Atelier A3 · Connecter une VM

## Objectif

Identifier les deux interfaces de la VM, observer la route par défaut et prouver chaque flux par un test.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`60-lab.yaml`](60-lab.yaml) | Configuration Netplan de l'interface privée, à copier dans `/etc/netplan/` sur la VM |

## Prérequis

- VM `UbuntuDev` préparée en [A2](../a2-vm-linux-conteneur-web/) (Ubuntu Server, Docker installé, compte `vboxuser`)
- VirtualBox sur l'hôte, accès à la console de la VM

### Réutiliser la VM de l'atelier A2

1. Arrêter `UbuntuDev` (`sudo poweroff`) : les adaptateurs réseau se modifient VM arrêtée.
2. Conserver l'adaptateur 1 en NAT tel que configuré en A2.
3. Appliquer les réglages de la section 1, puis redémarrer la VM.
4. Copier [`60-lab.yaml`](60-lab.yaml) dans `/etc/netplan/` (section 3).

## 1. Configuration VirtualBox

VM **arrêtée** :

1. Réseau privé hôte `HostNetwork` : masque `255.255.255.0`, réseau `192.168.56.0/24`. La plage DHCP a été ramenée à `192.168.56.100` – `192.168.56.199` pour que `192.168.56.20` reste hors plage.
2. VM > Configuration > Réseau :
    - Adaptateur 1 : **NAT** (inchangé)
    - Adaptateur 2 : **Host-only Network** (`HostNetwork`)

L'hôte (Mac) prend l'adresse `192.168.56.100` sur l'interface `bridge100`.

## 2. Interfaces de la VM

```bash
ip -br link
ip -br addr
```

| Interface | Rôle | Adresse |
|-----------|------|---------|
| `enp0s8` | NAT (adaptateur 1) | 10.0.2.15/24 (DHCP) |
| `enp0s9` | Réseau privé hôte (adaptateur 2) | 192.168.56.20/24 (statique) |
| `docker0` | Réseau des conteneurs | 172.17.0.1/16 (DOWN, pas de conteneur sur ce réseau à ce moment) |

> Le NAT est déjà `enp0s8` : l'interface privée est donc `enp0s9`, et non `enp0s8` comme dans l'exemple du TP.

## 3. Adresse statique avec Netplan

`/etc/netplan/60-lab.yaml` :

```yaml
network:
  version: 2
  ethernets:
    enp0s9:
      dhcp4: false
      addresses:
        - 192.168.56.20/24
```

```bash
sudo chmod 600 /etc/netplan/60-lab.yaml
sudo netplan generate
sudo netplan try        # configuration acceptée avec Entrée
ip -br addr
ip route
getent hosts ubuntu.com
```

## 4. Résultats dans la VM

- `enp0s9` : `UP`, `192.168.56.20/24`.
- Route par défaut : `default via 10.0.2.2 dev enp0s8` (le NAT reste la sortie vers Internet).
- Route du réseau privé : `192.168.56.0/24 dev enp0s9 proto kernel scope link src 192.168.56.20`.
- `getent hosts ubuntu.com` : résolution DNS OK (adresses IPv6 `2620:2d:4000:1::26/27/28`), donc la sortie par le NAT fonctionne.

## 5. Tests depuis le Mac (hôte)

Le conteneur Nginx de l'atelier A2 est relancé en publiant le port 8088 :

```bash
sudo docker run -d --name web-vm -p 8088:80 nginx:1.28-alpine
```

| Test | Commande | Résultat |
|------|----------|----------|
| ping | `ping 192.168.56.20` | 3/3 paquets reçus, 0 % de perte, ~0,5 ms |
| HTTP | `curl 192.168.56.20:8088` | page « Welcome to nginx! » |
| SSH | `ssh vboxuser@192.168.56.20` | connexion OK (après installation d'`openssh-server`) |

OpenSSH n'était pas installé dans la VM :

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

## 6. Dépannage rencontré

- Au début, `ping` donnait `No route to host` depuis le Mac et `curl` ne se connectait pas. Une fois le test refait après le démarrage de l'interface `bridge100` côté Mac et le conteneur relancé en 8088, les flux ont fonctionné.
- Le `curl` sur le port 8080 échouait parce que le conteneur publiait alors le port 8088.

## 7. Nettoyage

```bash
sudo docker rm -f web-vm
```

L'adresse statique `192.168.56.20` et l'adaptateur réseau privé hôte sont **conservés** : les ateliers B3 et B4 s'y connectent en SSH. Pour revenir à l'état de A2 :

```bash
sudo rm /etc/netplan/60-lab.yaml
sudo netplan apply
```

Puis, VM arrêtée, désactiver l'adaptateur 2 dans VirtualBox.

## 8. Analyse

- **NAT** (`enp0s8`) : sortie vers Internet via la route par défaut `10.0.2.2` ; la VM n'est pas joignable directement depuis l'hôte (il faut une redirection de port).
- **Réseau privé hôte** (`enp0s9`) : accès direct Mac ↔ VM sur `192.168.56.0/24`, sans route par défaut ni sortie vers Internet.
- Le ping prouve la connectivité IP (ICMP), le `curl` prouve que le port réellement utilisé (8088) est joignable : les deux tests distinguent un filtrage ICMP d'un défaut de routage.