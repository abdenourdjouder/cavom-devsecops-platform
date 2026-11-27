# Dépannage

Cette liste est l'**inventaire exact des points de diagnostic couverts par le
dépôt actuel**. Consulter les codes d'état et les journaux avant de modifier
un manifest. Ne stocker aucun secret dans les commandes de diagnostic
partagées.

## Liste exacte

1. **`Set GITLAB_ROOT_PASSWORD` / `POSTGRES_PASSWORD` au `docker compose config`.**  
   Copier `.env.example` vers `.env`, fournir des valeurs longues/uniques, puis
   relancer la vérification. Ne jamais coller le secret dans un ticket ou log.

2. **GitLab reste `unhealthy` ou prend plusieurs minutes.**  
   Vérifier `docker compose ps`, les événements et
   `docker compose logs --tail=300 gitlab`. Respecter la santé grace 180 s.
   Relever stockage, mémoire, ports 8443/2222/5443 et journaux Omnibus.

3. **`gitlab.localhost` ne s'ouvre pas.**  
   Vérifier la résolution `.localhost`, l'URL `GITLAB_EXTERNAL_URL`, le binding
   loopback et qu'aucun autre processus ne détient le port. L'adresse n'est pas
   destinée aux clients distants ; DNS/TLS/proxy sont nécessaires pour eux.

4. **SSH GitLab annonce le mauvais port.**  
   Faire correspondre `GITLAB_SSH_PORT`, l'adresse cliente, le port publié
   2222 et la clé. Le port 22 du conteneur n'est pas publié tel quel.

5. **Le registre externe répond en erreur TLS ou présente un certificat non fiable.**  
   Vérifier les fichiers `registry.localhost.crt/.key`, leurs SAN, droits,
   montage `/etc/gitlab/ssl` et la CA distribuée. L'endpoint externe attendu est
   `https://registry.localhost:5443`; l'endpoint interne Compose est
   `gitlab:5050`.

6. **`docker pull` depuis kind échoue vers `registry.localhost:5443`.**  
   `localhost` est résolu dans le nœud kind, pas sur l'hôte. Publier un endpoint
   routable avec DNS/TLS ou charger une image locale avec
   `kind-load-images.sh`.

7. **`Error: pull access denied` / `ImagePullBackOff`.**  
   Vérifier le nom de projet/registre, que `gitlab-regcred` existe dans le bon
   namespace, le type `kubernetes.io/dockerconfigjson`, le ServiceAccount et le
   token de lecture. Inspecter les événements sans afficher le secret :
   `kubectl get events`, `kubectl describe pod -n <namespace> <pod>`.

8. **Le Runner est `unhealthy`.**  
   Tester localement `http://127.0.0.1:9252/metrics` dans le conteneur,
   vérifier `/workspace` en écriture UID 1000, le volume de config et les logs.
   Le port 9252 n'est volontairement pas publié sur l'hôte.

9. **`replace-with-a-gitlab-runner-authentication-token`.**  
   Créer un token d'authentification réel dans GitLab, le mettre dans le
   fichier non versionné, protéger ce fichier avec mode 600 puis recréer le
   Runner. Ne pas réutiliser le registration token historique.

10. **Job GitLab : commande introuvable (`mvn`, `npm`, `trivy`, etc.).**  
    L'executor est `shell` ; il ignore les `image:` comme environnement de job.
    Utiliser des outils maintenus dans le Runner, ou passer à un executor
    Docker/Kubernetes configuré. L'exemple `config.docker-executor.toml.example`
    exige une API Docker rootless TLS externe `rootless-docker-endpoint:2376`;
    Compose ne la fournit pas et le socket hôte n'est pas le montage prévu.

11. **Runner ne peut pas ouvrir BuildKit.**  
    Vérifier `--profile buildkit`, la santé de `buildkit-rootless`, le socket
    `/run/buildkit/buildkitd.sock`, le volume partagé et le lancement UID 1000.
    Le `depends_on` Runner ne contrôle pas BuildKit. Ne pas monter le socket
    Docker comme raccourci.

12. **BuildKit : erreur d'utilisateur namespace, seccomp ou sandbox.**  
    Vérifier les paramètres noyau/id mapping de rootless, les deux relâchements
    seccomp/AppArmor du service et les capacités de l'hôte. Le flag CI
    `--oci-worker-no-process-sandbox` modifie le comportement du worker ; tester
    avec l'image/version réellement utilisée (`v0.20.2` CI vs `v0.23.2`
    Compose).

13. **SonarQube ne démarre pas.**  
    Tester la santé/résolution réseau PostgreSQL, les mots de passe `.env`,
    `vm.max_map_count >= 262144`, les file descriptors, mémoire/disque et les
    logs SonarQube/PostgreSQL. SonarQube a une grace 120 s.

14. **Pas de job `quality:sonar`.**  
    Les deux variables `SONAR_TOKEN` et `SONAR_HOST_URL` sont requises par la
    règle du job. Vérifier aussi la portée protected/branch/tag et que le Runner
    résout réellement l'hôte SonarQube.

15. **SonarQube : timeout ou Quality Gate attendue.**  
    Ouvrir le projet, examiner le serveur et sa Quality Gate, vérifier le token
    et `SONAR_HOST_URL` depuis le job. Le job attend au plus 600 s par défaut ;
    augmenter la valeur ne répare pas une analyse/requête réseau cassée.

16. **Trivy échoue sur HIGH/CRITICAL.**  
    Lire le JSON, SARIF et le tableau dans `security/reports/`, identifier le
    composant fixable et mettre à niveau. Une exception ne doit contenir que des
    constats approuvés et expirés à date ; `ignore-unfixed=true` ne voit que les
    constats exploitables/fixables selon la base Trivy. Vérifier l'accès
    `ghcr.io` si la base manque.

17. **Publication Maven `401/403`, endpoint introuvable.**  
    Vérifier que le job utilise `$CI_API_V4_URL/projects/$CI_PROJECT_ID/...`,
    `Job-Token` et `CI_JOB_TOKEN`, pas l'URL registre OCI externe :5443.
    Package Registry est activé et que le pipeline a l'autorisation du projet.

18. **Publication d'images échoue.**  
    Vérifier `CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_JOB_TOKEN`, l'authfile
    Skopeo et la présence des archives OCI. Les deux images sont scannées et
    placées sous `.oci/` avant publication ; l'absence d'une archive est une
    rupture des `needs`/artefacts ou du build.

19. **Déploiement CI échoue avant `apply` sur un secret absent.**  
    Le job exige la branche par défaut et `KUBE_CONFIG_BASE64`, et se place
    dans l'environnement `production`. Vérifier qu'il est protégé, les variables
    masquées/protégées, les deux publications réussies et le base64 décodé. Le
    script contrôle `gitlab-regcred` dans frontend/backend et
    `database-credentials` dans backend/database avant Kustomize.

20. **`kubectl apply` est refusé avec le compte déployeur.**  
    Comparer le kubeconfig aux trois Roles de déployeur. Ils ne permettent ni
    namespaces, secrets, ServiceAccounts, NetworkPolicies ni RBAC. Effectuer le
    bootstrap par un opérateur autorisé puis limiter le compte de mise à jour,
    ou définir une identité d'application explicitement autorisée.

21. **`database-credentials` absent au déploiement.**  
    Le secret n'est pas dans Kustomize. Créer les deux instances dans
    `cavom-backend` et `cavom-database`, ou déployer les ExternalSecrets après
    avoir installé le contrôleur et créé `cavom-secret-store`.

22. **Backend en `CreateContainerConfigError` ou échec DB.**  
    Vérifier `DB_URL`, `DB_USERNAME`, `SPRING_DATASOURCE_PASSWORD` ainsi que
    les deux secrets DB. Le ConfigMap référence le FQDN MySQL
    `mysql.cavom-database.svc.cluster.local:3306`. Les identifiants
    backend/base doivent être identiques.

23. **MySQL démarre mais les tables n'existent pas.**  
    JPA est en `ddl-auto=validate`; le ConfigMap `mysql-init-schema` est monté
    dans `/docker-entrypoint-initdb.d` mais n'est exécuté par MySQL que sur un
    datadir vide. Vérifier le PVC, l'exécution initiale et les logs. Les
    migrations d'un PVC existant ne sont pas fournies.

24. **Frontend sans endpoint / readiness sur 8080.**  
    Vérifier que le conteneur, les probes et la NetworkPolicy utilisent tous
    8080, que Nginx sert `/healthz` et que le Service 80 cible le port nommé
    `http`.

25. **NodePort 30080 inaccessible.**  
    Vérifier que kind existe, que son mapping est sur 127.0.0.1:30080, que le
    Service frontend est NodePort 30080, puis l'état/probes du pod 8080.

26. **`503` depuis Nginx ou frontend sans backend.**  
    Vérifier la NetworkPolicy, DNS `backend.cavom-backend.svc.cluster.local`,
    le Service 8080 et les probes Actuator `/actuator/health/liveness` et
    `/actuator/health/readiness`. Nginx cible maintenant le FQDN
    `backend.cavom-backend.svc.cluster.local:8080`.

27. **NetworkPolicies semblent ignorées sur kind.**  
    Inspecter le CNI et tester un trafic effectivement refusé. Des objets API
    ne garantissent pas l'application par un CNI minimal/non-conforme.

28. **L'image locale semble absente après `kind load`.**  
    Le script exige déjà les deux images dans le Docker local, sous les noms
    `registry.gitlab.com/cavom/platform/frontend:1.0.0` et
    `.../backend:1.0.0`, puis les charge dans le cluster choisi. Inspecter le
    nom, le contexte et le cluster avant de relancer.

29. **Kubernetes ou le script local conserve une image inattendue.**  
    Les manifests K8s utilisent `1.0.0`; la CI les remplace par tag commit/tag.
    Le script local utilise aussi `1.0.0` par défaut et `IfNotPresent` peut
    réutiliser le cache du nœud. Vérifier le tag fourni, recharger/tirer et contrôler le
    digest réellement déployé.

30. **Un secret apparaît dans un job ou un log.**  
    Révoquer immédiatement le token/mot de passe concerné, supprimer l'artefact
    ou l'accès, activer les réglages masked/protected et purger les historiques.
    Ne pas se contenter de retirer la ligne lors d'un commit suivant.

31. **Supprimer/recréer le cluster échoue encore sur les mêmes images/secrets.**  
    `kind-delete` supprime le cluster, pas les volumes de GitLab, Docker images
    locales ou variables GitLab. Refaire la chaîne de création, secrets,
    images, pull/chargement, apply et rollouts de manière explicite.

32. **Runner : push/pull vers `registry.localhost:5443` vise le mauvais hôte.**  
     Inspecter `$CI_REGISTRY` dans le job et sa résolution depuis le conteneur
     Runner, séparément de l'hôte. L'endpoint Docker interne est `gitlab:5050`,
     l'externe annoncé `registry.localhost:5443`. Fournir routage, CA et
     credentials adéquats à chaque client, sans registre insecure global.
