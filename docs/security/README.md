# Sécurité et décisions d'exploitation

## Modèle de confiance

Les frontières du dépôt sont :

- GitLab et variables protégées sont l'autorité CI ;
- les images et outils CI sont épinglés mais sont des dépendances externes ;
- Runner shell est le plus sensible : il exécute le dépôt sur son propre OS de
  conteneur, sans isolation `image:` ;
- BuildKit rootless restreint l'usage du daemon mais n'est pas équivalent à une
  sandbox générale ;
- le cluster Kubernetes sépare les tiers par namespaces et NetworkPolicies ;
- le poste opérateur contrôle les secrets de Docker, Kubernetes et GitLab.

Un Runner non approuvé, un tag d'outil modifié ou une variable non protégée
compromet la chaîne. Protéger branches, tags, environnement `production`,
tokens et paramètres de Runner est aussi important que les scans.

## Gates Trivy

Chaque scan est exécuté trois fois pour produire des preuves :

1. JSON avec code de sortie `0` ;
2. SARIF avec code de sortie `0` ;
3. table avec code de sortie `1` : échec du job si une
   vulnérabilité/configuration correspondant aux critères est trouvée.

Les scripts vulnérabilités passent explicitement `--severity HIGH,CRITICAL`. La
configuration ignore les constats `unfixed`, ignore `.git`, `.m2`,
`.npm-cache`, `.trivycache` et utilise un délai de 15 minutes.

| Gate | Cible | Contrôle |
|---|---|---|
| `security:filesystem` | `.` | vulnérabilités, secrets et misconfiguration |
| `security:dependencies` | frontend/backend | vulnérabilités des bibliothèques seulement |
| `security:secrets` | `.` | secrets seulement |
| `security:config` | `.` | configuration/IaC |
| image frontend/backend | archive OCI | vulnérabilités, secrets, misconfiguration et SBOM |

Les archives SBOM sont CycloneDX. Les rapports ont une rétention GitLab de
30 jours. Les vulnérabilités à solution absente sont volontairement ignorées
parce qu'une mise à niveau ne peut être proposée ; elles ne sont pas garanties
absentes. `trivy.yaml` a `exit-code: 0`, mais le troisième passage table
outrepasse cette valeur avec `--exit-code 1`, ce qui constitue le gate.

`security/policies/trivy-exceptions.yaml` est vide. Un ajout à
`.trivyignore` exige motif, approbation, propriétaire, date d'expiration et
raison cohérente avec la politique. Le dépôt n'automatise ni l'expiration ni
l'application du registre des exceptions : la revue est humaine.

## SonarQube : disponibilité n'est pas approbation

- le job n'existe pas sans `SONAR_TOKEN` **et** `SONAR_HOST_URL` ;
- avec variables, `sonar.qualitygate.wait=true` bloque jusqu'au verdict ;
- un Quality Gate serveur « failed », une erreur ou le timeout échouent le job ;
- l'image Community n'apporte pas les fonctions Enterprise, portefeuilles,
  branche décorée GitLab enrichie ou gouvernance multi-projet.

Le token doit appartenir à une identité technique avec le minimum d'accès.
`sonar.forceAuthentication=true` réduit les usages anonymes ; il ne protège pas
les projets contre une Quality Gate mal conçue. L'installation SonarQube n'est
pas haute disponibilité, les volumes ne sont pas sauvegardés ici et
PostgreSQL n'a pas de port hôte.

## Runner et BuildKit rootless

Le Runner Compose applique :

- UID/GID 1000, rootfs lecture seule, `tmpfs` pour `/workspace` ;
- `cap_drop: ALL`, `no-new-privileges:true` ;
- aucun socket Docker ou montage du host root ;
- concurrence 2, shell executor, métriques 9252 non publiées ;
- jeton dans un fichier hôte mode privé, non versionné.

Le Runner shell reste le défaut et ignore les directives `image:` des jobs.
L'exemple `config.docker-executor.toml.example` utilise une API Docker
rootless distante TLS sur `rootless-docker-endpoint:2376`. Cette API n'est pas
créée par Compose : son daemon, sa CA, ses certificats clients, sa résolution
DNS et ses limites de ressources sont une dépendance opérateur. La variante
n'emploie volontairement aucun socket Docker hôte.

BuildKit a un profil séparé, UID/GID 1000, état et socket dans volumes nommés,
et `cap_drop` implicite aux options Compose. Sa sécurité dépend de :

- `seccomp:unconfined` ;
- `apparmor:unconfined` ;
- `no-new-privileges:true`.

Ces relâchements sont requis par l'usage rootless choisi et limités au daemon
BuildKit, pas au Runner. Ils réduisent l'isolation et doivent être revus avec
la version du kernel. Le dépôt n'autorise ni Docker-in-Docker privilégié ni
socket Docker. L'image de BuildKit employée en CI (`v0.20.2`) diffère de
l'instance Compose (`v0.23.2`) : les deux chemins nécessitent validation
indépendante.

Le pipeline utilise `BUILDKITD_FLAGS=--oci-worker-no-process-sandbox` dans le
job d'image. Ce flag réduit le sandbox des processus du worker BuildKit
rootless et augmente le risque de build non fiable. Ne pas confondre ce job
d'image isolé (si executor compatible) avec le daemon rootless optionnel du
Compose.

## Secrets et variables

| Type | Emplacement attendu | À éviter |
|---|---|---|
| Compose initial | `.env` chmod 600 | image, Git, logs |
| token Runner | `runner/config.toml` chmod 600 | token de registration réutilisé |
| CI Sonar/Kube | variables masked/protected | variables non protégées |
| publication CI | `CI_JOB_TOKEN` temporaire | PAT permanent ou deploy password |
| DB Kubernetes | Secret par namespace ou External Secrets | ConfigMap contenant le mot de passe |
| pull image | `gitlab-regcred`, token de lecture | imagePullSecret partagé au repos Git |

Les ServiceAccounts applicatifs et `cavom-deployer` ont
`automountServiceAccountToken: false`. Les workloads applicatifs n'ont donc pas
de token API par défaut. Le kubeconfig de la CI est injecté indépendamment,
décodé en mode 0600 et supprimé avec le job.

Avant Kustomize, le script de déploiement vérifie `gitlab-regcred` dans les
namespaces frontend/backend et `database-credentials` dans backend/database.
Ces préchecks échouent vite sur un environnement incomplet ; ils n'attribuent
pas les droits nécessaires pour créer les secrets.

## RBAC Kubernetes

Chaque namespace contient un ServiceAccount `cavom-deployer` avec un Role
limité aux ressources listées :

- frontend/backend : Deployments, ReplicaSets, Services, ConfigMaps ;
- database : StatefulSets, Services, PersistentVolumeClaims.

Les permissions incluent suppression, mais pas namespaces, Nodes, ClusterRoles,
NetworkPolicies, Secrets, ServiceAccounts ou RBAC. Donc ce compte n'est
**pas suffisant** pour le `kubectl apply -k` complet tel qu'écrit. Le script CI
doit utiliser une identité séparée préautorisée à créer/gérer ces objets, ou
un bootstrap opérateur doit appliquer Kustomize avant que le déploiement
limité ne change les images. Aucun mécanisme de liaison automatique avec ces
ServiceAccounts n'est fourni.

## Isolation réseau Kubernetes

Les trois namespaces ont default-deny ingress/egress, puis :

- frontend : entrée TCP 8080 depuis tout IP, DNS vers `kube-system`, sortie
  backend TCP 8080 ;
- backend : entrée TCP 8080 seulement par le pod frontend, DNS et sortie MySQL
  3306 ;
- database : entrée MySQL seulement depuis le pod backend, aucune egress.

L'entrée frontend est volontairement large (`0.0.0.0/0`) parce qu'elle sert
de point d'entrée NodePort ; un ingress ou pare-feu devrait la restreindre.
Les règles mentionnent l'identité des pods, pas seulement les namespaces.
Le kind par défaut doit être vérifié avec son CNI : des YAML NetworkPolicy ne
constituent pas un contrôle si le CNI ne les applique pas.

## GitLab image versus kind load

`kubectl` ne déclenche pas un upload vers kind. Deux chemins différents :

1. **GitLab** : le nœud Kubernetes contacte le registre externe avec DNS/TLS et
   `gitlab-regcred`, tire l'image nominative et applique la policy de pull.
2. **`kind load`** : le script inspecte des images déjà présentes dans Docker
   sur l'hôte et les copie dans le daemon du nœud. Aucun token registry n'est
   alors testé, et le réseau GitLab n'est pas impliqué.

Les manifests sont épinglés à `1.0.0` avec `IfNotPresent`; la CI les remplace
par le tag commit ou tag Git. Le script local de kind conserve toutefois des
valeurs par défaut `latest`, qui peuvent réutiliser une ancienne couche. Pour
ce chemin, nommer explicitement l'image/tag prévu et contrôler le digest.

## Limites applicatives

Le frontend publie des en-têtes de sécurité Nginx (nosniff, DENY, referrer,
CSP) et son reverse proxy cible
`backend.cavom-backend.svc.cluster.local:8080`. Le Service écoute 80 côté
frontend puis 8080 dans le conteneur, exposé en NodePort 30080. L'API Spring a
CORS configurable et n'est pas exposée directement par le NodePort, ce qui
favorise l'accès via proxy. Le dépôt n'implique pas de SSO,
WAF, mTLS, chiffrement MySQL, gestion de sessions GitLab ou chiffrement de
volumes : ces éléments restent hors périmètre.
