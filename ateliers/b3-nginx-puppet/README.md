# Atelier B3 · Configurer Nginx avec Puppet

## Objectif

Installer Nginx avec Puppet (`puppet apply`, mode local), démarrer son service, vérifier que la configuration est stable à la seconde exécution, puis observer la remise en conformité après une modification manuelle.

## Fichiers

| Fichier | Rôle |
|---------|------|
| [`site.pp`](site.pp) | Point d'entrée : `include web_nginx` |
| [`modules/web_nginx/manifests/init.pp`](modules/web_nginx/manifests/init.pp) | Classe `web_nginx` : paquet, page `puppet.html`, service |

## Prérequis

- VM Ubuntu Server de l'atelier A2 (`ubuntuDevv`, utilisateur `vboxuser`), connexion en SSH depuis le Mac : `ssh vboxuser@192.168.56.20`
- Ubuntu 26.04.1 LTS (aarch64), dépôt Universe activé
- Puppet `8.10.0` (paquet `puppet-agent 8.10.0-6`, dépôt Ubuntu Universe)
- Port 80 libre dans la VM

### Réutiliser la VM de l'atelier A2

1. Démarrer `UbuntuDev` avec la configuration réseau de [A3](../a3-reseau-vm/) (adresse privée `192.168.56.20`).
2. Se connecter depuis le Mac : `ssh vboxuser@192.168.56.20`.
3. Copier les fichiers de ce dossier dans la VM, par exemple depuis le Mac :

```bash
scp -r site.pp modules vboxuser@192.168.56.20:~/puppet-nginx/
```

`puppet apply` s'exécute **sur la VM** : aucun serveur Puppet n'est nécessaire.

## 1. Préparation de la cible

Port 80 libre dans la VM :

```bash
sudo ss -tlnp | grep ':80 '
```

La commande n'affiche rien : aucun service n'occupe le port 80.

Installation de Puppet :

```bash
sudo apt update
sudo apt install -y puppet-agent
puppet --version
```

```
Installing:
  puppet-agent

Installing dependencies:
  augeas-lenses  facter  ruby  ruby3.3  [...]

Summary:
  Upgrading: 0, Installing: 42, Removing: 0, Not Upgrading: 50
  Download size: 12.9 MB
  [...]
Setting up puppet-agent (8.10.0-6) ...
puppet.service is a disabled or a static unit, not starting it.
```

```
8.10.0
```

## 2. Module et point d'entrée

```bash
mkdir -p ~/puppet-nginx/modules/web_nginx/manifests
cd ~/puppet-nginx
```

Arborescence :

```
puppet-nginx/
├── site.pp
└── modules/
    └── web_nginx/
        └── manifests/
            └── init.pp
```

### `modules/web_nginx/manifests/init.pp`

```puppet
class web_nginx {
  package { 'nginx':
    ensure => installed,
  }

  file { '/var/www/html/puppet.html':
    ensure  => file,
    content => "Configuration geree avec Puppet\n",
    mode    => '0644',
    require => Package['nginx'],
  }

  service { 'nginx':
    ensure  => running,
    enable  => true,
    require => Package['nginx'],
  }
}
```

Le paquet est installé en premier ; le fichier et le service en dépendent (`require`).

### `site.pp`

```puppet
include web_nginx
```

## 3. Vérification de la syntaxe

```bash
puppet parser validate site.pp modules/web_nginx/manifests/init.pp
```

Aucune sortie : la syntaxe des deux fichiers est valide.

## 4. Simulation (`--noop`)

```bash
sudo puppet apply --modulepath="$PWD/modules" --noop site.pp
```

```
Notice: Compiled catalog for ubuntudevv in environment production in 0.12 seconds
Notice: /Stage[main]/Web_nginx/Package[nginx]/ensure: created (noop)
Notice: /Stage[main]/Web_nginx/File[/var/www/html/puppet.html]/ensure: defined content as '{sha256}923fb12d92ff...' (noop)
Notice: /Stage[main]/Web_nginx/Service[nginx]/ensure: ensure changed 'stopped' to 'running' (noop)
Notice: Class[Web_nginx]: Would have triggered 'refresh' from 3 events
Notice: Stage[main]: Would have triggered 'refresh' from 1 event
Notice: Applied catalog in 0.11 seconds
```

La simulation liste les trois changements prévus (paquet, fichier, service) sans rien modifier sur la VM.

## 5. Première application

```bash
sudo puppet apply --modulepath="$PWD/modules" site.pp
```

```
Notice: Compiled catalog for ubuntudevv in environment production in 0.11 seconds
Notice: /Stage[main]/Web_nginx/Package[nginx]/ensure: created
Notice: /Stage[main]/Web_nginx/File[/var/www/html/puppet.html]/ensure: defined content as '{sha256}923fb12d92ff...'
Notice: Applied catalog in 4.26 seconds
```

Puppet installe le paquet `nginx` et crée la page `puppet.html`. Aucun changement n'est signalé pour `Service[nginx]` : le service est déjà démarré à la fin de l'installation du paquet.

Vérification :

```bash
systemctl is-active nginx
curl -fsS http://127.0.0.1/puppet.html
```

```
active
Configuration geree avec Puppet
```

## 6. Seconde application (idempotence)

```bash
sudo puppet apply --modulepath="$PWD/modules" site.pp
```

```
Notice: Compiled catalog for ubuntudevv in environment production in 0.11 seconds
Notice: Applied catalog in 0.10 seconds
```

Aucune ressource n'est modifiée : la page et le service restent dans le même état. La configuration est stable.

## 7. Écart manuel et remise en conformité

### Écart

Modification manuelle de la page :

```bash
echo "modifie a la main" | sudo tee /var/www/html/puppet.html
curl -fsS http://127.0.0.1/puppet.html
```

```
modifie a la main
modifie a la main
```

Le contenu du fichier ne correspond plus à celui déclaré dans le manifeste.

### Correction

```bash
sudo puppet apply --modulepath="$PWD/modules" site.pp
```

```
Notice: Compiled catalog for ubuntudevv in environment production in 0.11 seconds
Notice: /Stage[main]/Web_nginx/File[/var/www/html/puppet.html]/content: content changed '{sha256}1624160f4c3c...' to '{sha256}923fb12d92ff...'
Notice: Applied catalog in 0.11 seconds
```

Puppet détecte que l'empreinte (`sha256`) du fichier diffère de celle attendue et rétablit le contenu déclaré.

```bash
curl -fsS http://127.0.0.1/puppet.html
```

```
Configuration geree avec Puppet
```

La page est revenue à l'état décrit par le manifeste.

## 8. Nettoyage

Nginx est conservé pour l'atelier B4, qui gère le même service. Pour remettre la VM dans son état initial :

```bash
sudo systemctl disable --now nginx
sudo apt purge -y nginx nginx-common
sudo rm -f /var/www/html/puppet.html
rm -rf ~/puppet-nginx
```

Facultatif, pour retirer Puppet : `sudo apt purge -y puppet-agent && sudo apt autoremove -y`.

## 9. Bilan

| Étape | Résultat |
|-------|----------|
| `--noop` | 3 changements prévus, rien modifié |
| 1re application | paquet `nginx` installé, `puppet.html` créé |
| 2e application | aucun changement (idempotence) |
| Modification manuelle + application | contenu du fichier corrigé par Puppet |