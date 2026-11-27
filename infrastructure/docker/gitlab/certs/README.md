# Certificats TLS GitLab locaux

Ce répertoire reçoit uniquement les certificats générés lors de l'installation.
Ils ne sont pas versionnés.

Fichiers attendus :

- `gitlab.localhost.crt`
- `gitlab.localhost.key`
- `registry.localhost.crt`
- `registry.localhost.key`

Les certificats doivent couvrir les noms `gitlab`, `gitlab.localhost`,
`registry` et `registry.localhost`. Les clés privées doivent avoir des droits
`0600` et les certificats `0644`. La procédure de génération et l'ajout de la
CA à WSL2, aux jobs et à kind sont décrits dans la documentation d'installation.
