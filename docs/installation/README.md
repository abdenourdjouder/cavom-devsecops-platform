# Installation et commandes opérateur

Cette page décrit ce qu'**une personne opératrice devra exécuter plus tard**.
Aucune commande ci-dessous n'est une opération automatique du dépôt.

## Prérequis minimaux

- Docker Engine avec Docker Compose v2 ;
- hôte Linux avec plusieurs GiB de mémoire libre pour GitLab, SonarQube et
  PostgreSQL ; aucune limite de capacité n'est fournie par le dépôt ;
- pour kind : `kind`, `kubectl`, `docker` et un hôte compatible avec les nœuds ;
- noms `.localhost` résolus localement et ports 8443, 9000, 5443, 2222 et 30080
  libres ;
- accès réseau sortant pour les images des bases et, en CI, vers
  `ghcr.io` (bases Trivy), les registres Maven/npm/réglementaires et GitLab.

Les prérequis SonarQube Elasticsearch doivent inclure
`vm.max_map_count >= 262144`, assez de mémoire et de descripteurs de fichiers.
Il faut valider la politique du système hôte et, si nécessaire, appliquer une
valeur persistante selon l'administration de l'environnement.

## 1. Préparer secrets et certificats non versionnés

```sh
cd infrastructure/docker
cp .env.example .env
cp runner/config.toml.example runner/config.toml
chmod 600 .env runner/config.toml
```

Avant le démarrage, fournir dans `gitlab/certs` :

- `gitlab.localhost.crt` et `gitlab.localhost.key` ;
- `registry.localhost.crt` et `registry.localhost.key`.

Les certificats doivent couvrir `gitlab`, `gitlab.localhost`, `registry` et
`registry.localhost`; appliquer 0600 aux clefs, 0644 aux certificats. La
génération du matériel, le renouvellement et sa confiance dans le navigateur,
les jobs, le Runner et kind restent opérés manuellement.

Remplacer dans `.env` au minimum :

- `GITLAB_ROOT_PASSWORD`, valeur longue et aléatoire utilisée à
  l'initialisation ;
- `POSTGRES_PASSWORD` ;
- les URL et ports si les noms par défaut ne correspondent pas au routage.

Ne jamais committer `.env`, `runner/config.toml`, des kubeconfigs, ni les
templates de secrets une fois remplis. `.gitignore` couvre les deux premiers.

## 2. Démarrer la pile Compose

Démarrage sans BuildKit, uniquement après remplacement des placeholders :

```sh
docker compose config
docker compose up -d
docker compose ps
```

Démarrage avec le service BuildKit optionnel :

```sh
docker compose --profile buildkit up -d
docker compose --profile buildkit ps
```

Ne pas présenter cette commande comme l'enregistrement du Runner. L'ordre
effectif est :

1. PostgreSQL SonarQube puis SonarQube, après santé PostgreSQL ;
2. GitLab CE, processus Omnibus interne ;
3. Runner seulement après santé GitLab ;
4. BuildKit séparément si profil demandé ; sa santé ne retarde pas le Runner.

Adresses locales prévues :

- `https://gitlab.localhost:8443`
- `https://registry.localhost:5443` (endpoint externe TLS, pas une UI web)
- endpoint interne Compose TLS du registre : `gitlab:5050`
- SonarQube est
  `http://localhost:9000`
- SSH : `ssh://git@gitlab.localhost:2222`.

## 3. Initialiser GitLab et enregistrer le Runner

Après le verdict `healthy` de GitLab :

```sh
docker compose logs --tail=200 gitlab
```

Créer le projet/runner dans GitLab puis générer un **runner authentication
token**, pas l'ancien registration token. Le token, l'URL interne et le
clone URL appartiennent dans `runner/config.toml`, lequel ne doit pas être
versionné :

```toml
url = "https://gitlab.localhost:8443/"
clone_url = "https://gitlab/"
tls-ca-file = "/etc/gitlab-runner/certs/gitlab.localhost.crt"
token = "AUTHENTICATION_TOKEN_REEL"
executor = "shell"
```

Puis recréer le Runner avec le fichier :

```sh
docker compose up -d --force-recreate runner
docker compose exec runner gitlab-runner verify
```

Le conteneur n'est pas interactif lors du démarrage. L'option `register` n'est
pas orchestrée par le dépôt ; effectuer l'obtention/enregistrement selon la
version GitLab utilisée ou renseigner directement le token d'authentification.
Le Runner monte le répertoire de certificats en lecture seule sous
`/etc/gitlab-runner/certs` et reçoit aussi
`GITLAB_INTERNAL_API_URL=https://gitlab/api/v4` et
`GITLAB_INTERNAL_REGISTRY=gitlab:5050`; cet endpoint est lui-même TLS.

### Limite structurante du Runner

L'executor est `shell`. Il ne lance pas les images `node`, `maven`, `trivy`,
`sonar-scanner`, `buildkit`, `skopeo` ou `kubectl` déclarées dans les jobs
GitLab CI. Il faut explicitement choisir et opérer un executor compatible, ou
installer/maintenir sur le Runner chaque outil et chaque version attendue.
Le dépôt fournit maintenant un exemple `config.docker-executor.toml.example`,
mais il suppose une **API Docker rootless déjà gérée en dehors du Compose**
à `tcp://rootless-docker-endpoint:2376`, avec TLS, CA/certificats clients,
DNS/réseau et capacité administrés par l'opérateur. Il ne faut pas monter le
socket Docker hôte pour activer cette variante.

Le Runner est UID/GID 1000, rootfs en lecture seule, sans capacité, sans socket
Docker, avec `/workspace` en `tmpfs`. Installer des outils sur le conteneur
après son démarrage ne survit donc pas à sa recréation.

## 4. Configurer SonarQube

Au premier accès :

1. vérifier `http://localhost:9000` ;
2. remplacer immédiatement le mot de passe administrateur initial ;
3. créer le projet correspondant à `SONAR_PROJECT_KEY` ou autoriser sa création ;
4. créer et stocker un token d'analyse ;
5. configurer une Quality Gate volontairement.

La CI utilise l'attente bloquante :

```text
sonar.qualitygate.wait=true
sonar.qualitygate.timeout=600 secondes par défaut
```

`SONAR_HOST_URL` doit être atteignable **depuis le Runner**, par exemple le nom
Docker `sonarqube` dans ce réseau, et non par supposition depuis le navigateur.
Pour le Runner shell fourni, `http://sonarqube:9000` est une hypothèse de
routage interne à confirmer.

## 5. Préparer les variables protégées GitLab

Créer uniquement dans GitLab, avec portée adaptée :

```text
SONAR_HOST_URL
SONAR_TOKEN                     masked + protected
KUBE_CONFIG_BASE64              masked + protected
```

Le secret `CI_JOB_TOKEN` est fourni par GitLab ; ne pas le créer comme
variable. Restreindre `KUBE_CONFIG_BASE64` et `SONAR_TOKEN` aux branches/tags
protégés. Protéger aussi l'environnement nommé `production`.

## 6. Créer et utiliser le cluster kind

À la racine du dépôt :

```sh
infrastructure/kubernetes/scripts/kind-create.sh
kind get clusters
kubectl --context kind-cavom-devsecops get nodes
```

La configuration utilise `kindest/node:v1.31.4` et mappe seulement
`127.0.0.1:30080` vers le NodePort `30080`.

Les ports applicatifs sont déjà alignés : frontend/Nginx 8080, NodePort 30080,
backend 8080 et MySQL 3306. Le backend reçoit `DB_URL`, `DB_USERNAME` et
`SPRING_DATASOURCE_PASSWORD`; le ConfigMap d'initialisation MySQL est inclus.
Créer les secrets DB dans les deux namespaces applicables, et
`gitlab-regcred` dans `cavom-frontend` et `cavom-backend`. Les templates sont
sous `infrastructure/kubernetes/examples/` ou `templates/` ; ils ne font pas
partie de `kustomization.yaml`.

### Option A : images locales kind

Construire/nommer les deux images dans le daemon Docker de l'hôte, avec les
noms effectivement référencés, puis :

```sh
infrastructure/kubernetes/scripts/kind-load-images.sh
infrastructure/kubernetes/scripts/deploy.sh
```

`kind-load-images.sh` exige que `docker image inspect` trouve déjà les deux
images. `kind load` copie les couches **dans le nœud** ; il ne publie pas vers
GitLab ni ne teste l'authentification du registre.

### Option B : images tirées depuis GitLab

Faire correspondre les noms d'image des Deployments avec le projet du registre,
créer `gitlab-regcred` (token de lecture seul), garder
`imagePullPolicy: IfNotPresent` sous contrôle, puis appliquer :

```sh
kubectl --context kind-cavom-devsecops apply -k infrastructure/kubernetes
```

Les ServiceAccounts frontend/backend sont configurés avec
`imagePullSecrets: gitlab-regcred`; ce secret doit exister avant la création de
pods. Le registre accessible sur `127.0.0.1:5443` de l'hôte n'est pas
`registry.localhost:5443` depuis un nœud kind. Un registre TLS privé doit être
rendu atteignable par DNS/routage, sa CA installée dans les nœuds/jobs et ses
credentials fournis, ou les images doivent être transférées localement.

## 7. Création du kubeconfig de déploiement

`ci-cd/scripts/deploy.sh` décode `KUBE_CONFIG_BASE64`, l'écrit en mode privé,
vérifie `gitlab-regcred` dans frontend/backend et
`database-credentials` dans backend/database, applique Kustomize, remplace les
deux images et attend les rollouts. Le
kubeconfig fourni doit avoir l'ensemble des droits nécessaires, incluant
création des namespaces/RBAC/ressources. Les trois ServiceAccounts
`cavom-deployer` n'ont pas de token monté et ne produisent pas automatiquement
un kubeconfig.

Avant de l'encoder :

```sh
kubectl config current-context
kubectl config view --minify --raw
base64 < fichier-kubeconfig-deployeur > kubeconfig.base64
```

Le contenu base64 demeure un secret, pas une obfuscation. Le mode d'obtention
d'un token de ServiceAccount doit suivre la politique de la cible Kubernetes.

## 8. Hors laboratoire

Pour un usage exposé :

- placer GitLab, le registre et SonarQube derrière DNS et TLS authentifié ;
- rediriger ou supprimer les ports loopback ;
- définir sauvegardes/restauration et rétention des volumes GitLab, SonarQube et
  MySQL ;
- configurer SMTP, stockage d'objets, observabilité, CNI NetworkPolicy,
  certificat de registre et distribution de secrets ;
- utiliser des tokens de déploiement/pull au moindre privilège ;
- soumettre les changements applicatifs/K8s à une revue séparée.
