# Atelier B4 · Déployer Nginx avec Ansible

## Objectif

Vérifier l'accès SSH, appliquer un playbook Ansible pour déployer Nginx et interpréter les changements rapportés.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`inventory.ini`](inventory.ini) | Groupe `targets` contenant la VM `ubuntu-dev` |
| [`web.yml`](web.yml) | Playbook : paquet Nginx, page `ansible.html`, service |

Aucun secret n'est versionné : la connexion utilise la clé SSH de l'utilisateur (hors dépôt) et le mot de passe `sudo` est saisi à l'exécution (`-K`).

## Prérequis

- **Poste de contrôle** : Mac (macOS), Ansible (`ansible-core` 2.21) installé avec Homebrew (`brew install ansible`)
- **Cible** : VM `UbuntuDev` (Ubuntu Server, utilisateur `vboxuser`), joignable en SSH sur le réseau privé hôte à l'adresse `192.168.56.20`, avec `openssh-server` et `python3`
- Connexion par clé SSH ; `sudo` demandé pour les tâches qui nécessitent une élévation (`-K`)

### Réutiliser la VM de l'atelier A2

1. Démarrer `UbuntuDev` avec la configuration réseau de [A3](../a3-reseau-vm/) (`192.168.56.20`, `openssh-server` installé).
2. Depuis le Mac, installer la clé SSH puis tester la connexion avant Ansible :

```bash
ssh-copy-id vboxuser@192.168.56.20
ssh vboxuser@192.168.56.20
```

À la première connexion, comparer l'empreinte affichée avec celle lue sur la console de la VM (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`). La vérification des clés d'hôte reste activée.

3. Si seul le NAT est utilisé, créer une redirection SSH dans VirtualBox et adapter `ansible_host` et `ansible_port` dans `inventory.ini`.

Toutes les commandes Ansible se lancent depuis ce dossier, sur le Mac.

## 1. Inventaire et test de connexion

`inventory.ini` :

```ini
[targets]
ubuntu-dev ansible_host=192.168.56.20 ansible_user=vboxuser
```

```bash
ansible -i inventory.ini targets -m ansible.builtin.ping
```

```
[WARNING]: Host 'ubuntu-dev' is using the discovered Python interpreter at '/usr/bin/python3.14', [...]
ubuntu-dev | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.14"
    },
    "changed": false,
    "ping": "pong"
}
```

Ansible exécute bien un module sur la cible. L'avertissement indique seulement que l'interpréteur Python a été détecté automatiquement (`/usr/bin/python3.14`).

## 2. Playbook

`web.yml` :

```yaml
---
- name: Configurer le serveur web
  hosts: targets
  become: true
  tasks:
    - name: Installer Nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true
        cache_valid_time: 3600

    - name: Déployer une page de test
      ansible.builtin.copy:
        dest: /var/www/html/ansible.html
        content: "Configuration geree avec Ansible\n"
        owner: root
        group: root
        mode: "0644"

    - name: Activer et démarrer Nginx
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
```

## 3. Vérification de la syntaxe

```bash
ansible-playbook -i inventory.ini web.yml --syntax-check
```

```
playbook: web.yml
```

## 4. Première exécution

```bash
ansible-playbook -i inventory.ini web.yml -K
```

```
BECOME password:

PLAY [Configurer le serveur web] ***********************************

TASK [Gathering Facts] *********************************************
ok: [ubuntu-dev]

TASK [Installer Nginx] *********************************************
ok: [ubuntu-dev]

TASK [Déployer une page de test] ***********************************
changed: [ubuntu-dev]

TASK [Activer et démarrer Nginx] ***********************************
ok: [ubuntu-dev]

PLAY RECAP *********************************************************
ubuntu-dev                 : ok=4    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

- `Déployer une page de test` : **changed**, la page `ansible.html` n'existait pas et vient d'être créée.
- `Installer Nginx` : **ok**, Nginx était déjà installé sur la VM (atelier Puppet), aucune action nécessaire.
- `Activer et démarrer Nginx` : **ok**, le service était déjà actif et activé au démarrage.

## 5. Seconde exécution (idempotence)

```bash
ansible-playbook -i inventory.ini web.yml -K
```

```
TASK [Gathering Facts] *********************************************
ok: [ubuntu-dev]

TASK [Installer Nginx] *********************************************
ok: [ubuntu-dev]

TASK [Déployer une page de test] ***********************************
ok: [ubuntu-dev]

TASK [Activer et démarrer Nginx] ***********************************
ok: [ubuntu-dev]

PLAY RECAP *********************************************************
ubuntu-dev                 : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

`changed=0` : aucune tâche n'a modifié la cible.

## 6. Simulation (`--check --diff`)

```bash
ansible-playbook -i inventory.ini web.yml -K --check --diff
```

```
TASK [Installer Nginx] *********************************************
ok: [ubuntu-dev]

TASK [Déployer une page de test] ***********************************
ok: [ubuntu-dev]

TASK [Activer et démarrer Nginx] ***********************************
ok: [ubuntu-dev]

PLAY RECAP *********************************************************
ubuntu-dev                 : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

La simulation ne prévoit aucun changement et n'affiche aucune différence : la cible est déjà conforme au playbook.

## 7. Vérification de la page

```bash
curl http://192.168.56.20/ansible.html
```

```
Configuration geree avec Ansible
```

La page est servie par Nginx depuis le Mac.

## 8. Interprétation des résultats

| Statut | Signification |
|--------|---------------|
| `ok` | La tâche s'est exécutée avec succès et l'état de la cible était déjà conforme : rien n'a été modifié |
| `changed` | La tâche s'est exécutée avec succès et a **modifié** la cible (ici, création de `ansible.html`) |

Le `PLAY RECAP` permet de les distinguer : `changed=1` à la première exécution, `changed=0` à la seconde.

## 9. Nettoyage

Retirer la page de test (commande ad hoc depuis le Mac) :

```bash
ansible -i inventory.ini targets -b -K -m ansible.builtin.file -a "path=/var/www/html/ansible.html state=absent"
```

Pour remettre la VM dans son état initial, arrêter et désinstaller Nginx :

```bash
ansible -i inventory.ini targets -b -K -m ansible.builtin.service -a "name=nginx state=stopped enabled=false"
ansible -i inventory.ini targets -b -K -m ansible.builtin.apt -a "name=nginx,nginx-common state=absent purge=true"
```

## 10. Comparaison avec Puppet

| | Puppet (atelier B3) | Ansible (atelier B4) |
|---|---|---|
| Où tourne l'outil | Sur la VM elle-même (`puppet apply`) | Sur le Mac (poste de contrôle) |
| Accès à la cible | Aucun : le catalogue est compilé et appliqué en local | SSH (clé) depuis le poste de contrôle, avec `sudo` (`become`) |
| Description | Ressources `package`, `file`, `service` dans une classe d'un module, appelée par `site.pp` | Tâches `apt`, `copy`, `service` dans un playbook, ciblant le groupe `targets` |
| Ordre | Relations de dépendance explicites (`require => Package['nginx']`) | Ordre d'écriture des tâches, exécutées de haut en bas |
| Simulation | `--noop` | `--check --diff` |
| Preuve de conformité | Seconde application sans changement, puis correction du fichier modifié à la main | Seconde exécution avec `changed=0` et simulation sans différence |

Les deux outils gèrent un paquet, un fichier et un service de façon idempotente : rejouer la configuration ne modifie rien si la cible est déjà conforme.