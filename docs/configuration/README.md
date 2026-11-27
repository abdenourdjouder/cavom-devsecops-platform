# Configuration

## Fichier `.env` Compose

| Variable | Défaut d'exemple | Usage / contrainte |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `cavom-devsecops` | nom du projet Compose |
| `GITLAB_HTTPS_PORT` | `8443` | port loopback HTTPS GitLab |
| `GITLAB_SSH_PORT` | `2222` | port loopback SSH, écrit dans Omnibus |
| `GITLAB_REGISTRY_PORT` | `5443` | port loopback TLS du registre |
| `SONARQUBE_HTTP_PORT` | `9000` | port loopback SonarQube |
| `GITLAB_EXTERNAL_URL` | `https://gitlab.localhost:8443` | URL annoncée aux utilisateurs |
| `GITLAB_REGISTRY_EXTERNAL_URL` | `https://registry.localhost:5443` | URL annoncée aux clients registry |
| `GITLAB_ROOT_PASSWORD` | placeholder | requis ; initialisation GitLab seulement |
| `POSTGRES_USER` / `POSTGRES_DB` | `sonar` | identité/base SonarQube |
| `POSTGRES_PASSWORD` | placeholder | requis au démarrage SonarQube |
| `GITLAB_RUNNER_CONFIG` | `./runner/config.toml` | fichier Runner hôte, non versionné |

Le mot de passe root GitLab n'est consommé que lors de l'initialisation de sa
base Omnibus. Le changer dans `.env` ensuite ne change pas le compte existant.
Les trois volumes `gitlab-config`, `gitlab-logs` et `gitlab-data` forment une
unité de sauvegarde à traiter ensemble.

## Configuration GitLab

`gitlab.rb` annonce GitLab en HTTPS sur 443 interne et active les packages et
le registre ; Prometheus est désactivé. `registry_nginx` écoute en TLS sur 5050,
avec redirection GitLab HTTP vers HTTPS et Let's Encrypt désactivé. Le montage
`gitlab/certs` fournit les quatre certificats/clefs privés locaux.

### Registre : TLS et routage

- Le nom externe annoncé est `https://registry.localhost:5443`.
- L'endpoint interne Docker TLS est `gitlab:5050` (`https://gitlab:5050`
  pour les clients OCI) ; il ne doit pas être confondu
  avec l'URL publique TLS ni être exposé comme un nom client universel.
- Le port `127.0.0.1:5443` est inaccessible sous ce nom depuis kind, une VM ou
  un autre hôte, sauf routage explicite.
- Un client trust store doit connaître le certificat du registre ; éviter toute
  configuration globale « insecure registry » en production.
- Si un proxy TLS termine `registry.<domaine>`, transmettre Host/headers
  correctement et garantir que les clients suivent cette URL.
- La valeur `registry.localhost:5443` fournie par GitLab se résout localement
  au Runner et pas nécessairement vers le service GitLab. Tester séparément
  l'URL annoncée depuis le Runner et les nœuds kind. Sur Compose,
  `gitlab:5050` désigne le conteneur, mais ne devient pas automatiquement la
  valeur `$CI_REGISTRY` publiée par GitLab.
- Le CI écrit un authfile Skopeo temporaire avec `CI_JOB_TOKEN`, et l'efface à
  la sortie.
- Le job pousse en tag court/tag Git ou, sur la branche par défaut, également
  `latest`.

### Fonctionnalités GitLab CE

Le produit est l'édition **Community Edition**, pas l'édition Ultimate/Premium.
Le dépôt utilise son serveur Git, ses Merge Requests, le pipeline CI, le
registre de conteneurs et le Package Registry Maven. GitLab CE peut également
fournir d'autres formats de package natifs, selon sa configuration/version,
sans qu'ils soient utilisés ici.

Les tableaux de bord de sécurité avancés, la gestion des politiques et
conformité enrichies, l'analyse de risque multi-projet et certaines règles
d'approbation/protection sont des capacités Enterprise absentes ou limitées.
Le dossier n'inclut pas d'intégration de SAST DAST IAST GitLab, de gestion de
vulnérabilités serveur, de license scanning ou de gestion centralisée des
exceptions. Trivy, SonarQube et les protections CI sont les contrôles fournis.

## Endpoint Maven

Le script `publish-maven.sh` déploie l'artefact avec :

```text
altDeploymentRepository=gitlab-maven::default:
  $CI_API_V4_URL/projects/$CI_PROJECT_ID/packages/maven
```

Pour le GitLab de ce dépôt, hors d'un job, la forme visible est donc :

```text
https://gitlab.localhost:8443/api/v4/projects/<project-id>/packages/maven
```

ou l'équivalent HTTPS annoncé. Il ne s'agit pas du hostname distinct du
registre OCI (`registry.localhost:5443`). Le client Maven utilise l'ID serveur
`gitlab-maven` avec un en-tête `Job-Token: $CI_JOB_TOKEN`. Ce token est de
durée courte et limité au pipeline. Aucun dépôt Maven en lecture n'est ajouté
dans `pom.xml`, aucun artifact proxy ni mirroring n'est fourni ; le téléchargement
reste le mécanisme standard de Maven configuré ailleurs par l'opérateur.

Publication utilisée dans le script :

```sh
mvn --batch-mode --no-transfer-progress --errors \
  -s "$CI_PROJECT_DIR/.auth/maven-settings.xml" \
  -DskipTests \
  -DaltDeploymentRepository="gitlab-maven::default::$repository" \
  org.apache.maven.plugins:maven-deploy-plugin:3.1.2:deploy
```

## Variables CI et secrets

| Variable | Source prévue | Caractère |
|---|---|---|
| `CI_JOB_TOKEN` | GitLab | court, automatique, jamais stocké manuellement |
| `CI_REGISTRY`, `CI_REGISTRY_USER` | GitLab | automatiques |
| `SONAR_HOST_URL` | Settings CI/CD | protected si nécessaire, URL interne/accessible au job |
| `SONAR_TOKEN` | Settings CI/CD | masked, protected, minimum 600 s de Gate |
| `KUBE_CONFIG_BASE64` | Settings CI/CD | masked, protected, scope de déploiement |
| `SONAR_PROJECT_KEY` / `SONAR_PROJECT_NAME` | optionnelles CI | identifiants projet, pas secrets |
| `SONAR_QUALITY_GATE_TIMEOUT_SECONDS` | optionnelle CI | défaut 600 |
| `ROLLOUT_TIMEOUT` | optionnelle CI | défaut `5m` |

Mettre des valeurs de secret dans un `ConfigMap`, dans une variable GitLab non
masquée, dans l'historique Git ou dans l'image est interdit par conception.
Les fichiers temporaires `.auth`, `.kube`, `maven-settings.xml` et l'authfile
Skopeo sont mode privé et supprimés par un trap.

## Configuration application Spring Boot

Le backend lit :

```text
SERVER_PORT       défaut 8080
DB_URL            défaut jdbc:mysql://database:3306/cavom
DB_USERNAME       obligatoire
SPRING_DATASOURCE_PASSWORD (par convention Spring)
DB_POOL_SIZE      défaut 10
ALLOWED_ORIGIN    défaut http://localhost:8080
```

Le fichier `config.example.env` documente `DB_URL`, `DB_USERNAME`,
`SPRING_DATASOURCE_PASSWORD` et `ALLOWED_ORIGIN`. Le ConfigMap K8s fournit
désormais `DB_URL=jdbc:mysql://mysql.cavom-database.svc.cluster.local:3306/cavom`
et `ALLOWED_ORIGIN=http://localhost:30080`. Les variables `DB_USERNAME` et
`SPRING_DATASOURCE_PASSWORD` proviennent du secret `database-credentials`.
Les probes Kubernetes utilisent `/actuator/health/liveness` et
`/actuator/health/readiness`; le healthcheck de l'image backend utilise
`/actuator/health`.

Le StatefulSet MySQL monte le ConfigMap `mysql-init-schema` dans
`/docker-entrypoint-initdb.d`. Ce mécanisme initialise uniquement un volume de
données vide ; il ne constitue pas une migration au changement de version.

## Secrets Kubernetes

`database-credentials` doit exister :

- dans `cavom-backend` avec `username`, `password` ;
- dans `cavom-database` avec `username`, `password`, `root-password`.

Deux modèles sont fournis :

- `examples/database-credentials.example.yaml`, à adapter puis appliquer hors
  Git ;
- `templates/external-secrets.example.yaml`, nécessitant External Secrets
  Operator et `ClusterSecretStore/cavom-secret-store`.

Les templates ne sont pas inclus dans Kustomize. Le backend et MySQL doivent
lire la même valeur utilisateur/mot de passe.

Pour l'image privée, `gitlab-regcred` doit exister dans `cavom-frontend` et
`cavom-backend`, soit depuis l'exemple Docker config JSON, soit depuis
`templates/gitlab-image-pull-external-secret.example.yaml`. Ce secret est
référencé par les ServiceAccounts applicatifs.

## Configuration du Runner

`config.toml.example` fixe `concurrent=2`, un executor shell, un intervalle de
3 secondes, `FF_ENABLE_JOB_CLEANUP`, `/workspace/builds` et `/workspace/cache`.
Il contacte l'API annoncée sur `https://gitlab.localhost:8443/`, clone via
`https://gitlab/` et fait confiance à
`/etc/gitlab-runner/certs/gitlab.localhost.crt`.
`/workspace` est un `tmpfs` mode 0700 UID 1000 : cache et builds disparaissent au
redémarrage. Le cache logique GitLab sert à réutiliser des dépendances, pas à
promettre une persistance locale.

`config.docker-executor.toml.example` fournit une alternative Docker avec
`host = "tcp://rootless-docker-endpoint:2376"`, `tls_verify=true`, aucune
privilège et `no-new-privileges=true`. Ce n'est pas un daemon livré par
Compose : l'opérateur doit fournir séparément DNS/routage, service rootless,
certificats clients/CA, sécurité et capacité. Aucun socket Docker hôte n'est
monté ; ne pas remplacer cette API TLS distante par `/var/run/docker.sock`.

`BUILDKIT_HOST` est injecté sous
`unix:///run/buildkit/buildkitd.sock`, mais le socket n'existe que lorsque le
profil `buildkit` fonctionne et que le volume est monté. Le job actuel appelle
`buildctl-daemonless.sh`, qui dépend aussi de l'image/outil disponible dans son
environnement. Ne pas activer `privileged` ou le socket Docker pour contourner
la contrainte.

## SonarQube

Community force l'authentification, désactive la télémétrie, écoute sur 9000
et utilise uniquement PostgreSQL. Les propriétés CI par défaut analysent
`application/frontend/src` et `application/backend/src/main`, récupèrent les
tests et le rapport JUnit backend et exigent `application/backend/target/classes`.

La Quality Gate est **côté serveur** : ajouter un token ne crée pas une politique.
Si elle n'existe pas ou reste en attente, le job n'est pas la preuve d'une
acceptation. Les Community Quality Gates restent une fonction locale de
qualité ; les branches/pull requests décorées et les offres Enterprise
nécessitent des produits/configurations supplémentaires.
