# TP3 · OpenTofu avancé

Deux environnements locaux indépendants, chacun dans son dossier et avec son propre état OpenTofu. Ils utilisent tous les deux les ports 3000 et 8080 : on les lance **l'un après l'autre**.

| Pile | Dossier | Contenu | Preuve |
|------|---------|---------|--------|
| Plateforme DevSecOps | [`devsecops/`](devsecops/) | Gitea, Jenkins, SonarQube, PostgreSQL | Les 4 interfaces répondent, SonarQube `UP` et connecté à PostgreSQL, plan stable, dépôt Gitea conservé après redémarrage |
| Supervision | [`supervision/`](supervision/) | Appli Node.js, Prometheus, Grafana, Loki, Alloy | Cible `node` `UP`, compteur et journaux visibles dans Grafana, 9 requêtes = 9 lignes |

## Points communs

- Fournisseur `kreuzwerker/docker` **3.7.0**. La 3.6.1 de l'énoncé ne s'installe plus, sa clé de signature a expiré.
- Ports publiés uniquement sur `127.0.0.1`.
- Volumes nommés gérés par OpenTofu : le plan de destruction les supprime, il faut donc sauvegarder avant.
- Images conservées en cache (`keep_locally = true`).
- `terraform.tfstate*`, `*.tfplan`, `terraform.tfvars` et `.terraform/` sont ignorés par Git. `.terraform.lock.hcl` et `terraform.tfvars.example` sont versionnés.

## Enchaînement réalisé

```bash
cd devsecops   && tofu init && tofu plan -out=devops.tfplan && tofu apply devops.tfplan
# vérifications, puis :
tofu plan -destroy -out=devops-destroy.tfplan && tofu apply devops-destroy.tfplan

cd ../supervision && tofu init && tofu plan -out=monitoring.tfplan && tofu apply monitoring.tfplan
```

Le détail des commandes, des sorties et du nettoyage se trouve dans le README de chaque pile.
