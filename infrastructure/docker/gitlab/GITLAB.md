# GitLab CE

The Compose stack uses the all-in-one GitLab CE 18.1.2 image and exposes its UI, SSH transport, native container registry, and all package registries through GitLab's Omnibus services. GitLab's own database and Redis are internal Omnibus-managed dependencies; the separate Postgres service belongs exclusively to SonarQube.

The default loopback bindings and `.localhost` hostnames are for local infrastructure only. Production requires an external TLS proxy (or a TLS-enabled Omnibus configuration), trusted certificates, DNS entries, and restrictive firewall rules. The browser-facing URL, registry URL, and SSH port must describe the addresses reachable by users; they cannot remain `.localhost`.

`gitlab.rb` enables Maven, npm, PyPI, Generic and the other registry endpoints supplied by GitLab through the built-in package registry. Their endpoints are served by GitLab on its HTTP port; the container registry separately uses port 5050. No registry credentials are committed.

Copy `.env.example` to `.env` and replace both `GITLAB_ROOT_PASSWORD` and `POSTGRES_PASSWORD`. The root password is consumed only during GitLab's initial database initialization. Back up all three `gitlab-*` volumes together. Configure object storage, SMTP, backups, and public TLS separately according to the deployment environment.
