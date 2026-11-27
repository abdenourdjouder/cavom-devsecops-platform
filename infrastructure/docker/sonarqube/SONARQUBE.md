# SonarQube

SonarQube Community 2025.1 is supplied with PostgreSQL 16 rather than its H2 development database. H2 is unsuitable for persistent multi-component operation, so Postgres is a technical SonarQube dependency and not an extra application component. The database is network-internal and has no host-published port.

Database credentials are supplied only through `.env` and the official `SONAR_JDBC_*` environment variables. SonarQube forces authentication and disables telemetry. The initial SonarQube administrator credential is not stored in this repository and must be changed immediately after first use.

The host must satisfy the SonarQube Elasticsearch Linux requirements (`vm.max_map_count` at least 262144, adequate file descriptors and memory) before the service is operated. Port 9000 remains bound to loopback by Compose. Expose it through a TLS-terminating, access-controlled proxy for production, and back up the Postgres volume and the `sonarqube-data` volume consistently.

SonarQube is not configured with Java 17 here because the image contains its supported runtime. Any external scanner used against it should use its documented supported JRE; Java 17 remains the minimum scanner constraint for projects that explicitly select a Java 17 toolchain.
