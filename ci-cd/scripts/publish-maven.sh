#!/bin/sh
set -eu

: "${CI_JOB_TOKEN:?CI_JOB_TOKEN is required by the GitLab runner}"
: "${CI_PROJECT_ID:?CI_PROJECT_ID is required by the GitLab runner}"
: "${CI_API_V4_URL:?CI_API_V4_URL is required by the GitLab runner}"

repository="${GITLAB_INTERNAL_API_URL:-$CI_API_V4_URL}/projects/$CI_PROJECT_ID/packages/maven"
umask 077
mkdir -p "$CI_PROJECT_DIR/.auth"
cat > "$CI_PROJECT_DIR/.auth/maven-settings.xml" <<EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <servers>
    <server>
      <id>gitlab-maven</id>
      <configuration>
        <httpHeaders>
          <property>
            <name>Job-Token</name>
            <value>${CI_JOB_TOKEN}</value>
          </property>
        </httpHeaders>
      </configuration>
    </server>
  </servers>
</settings>
EOF

cleanup() {
  rm -f "$CI_PROJECT_DIR/.auth/maven-settings.xml"
}
trap cleanup EXIT HUP INT TERM

cd "${BACKEND_DIR:-application/backend}"
# shellcheck disable=SC2086
mvn ${MAVEN_CLI_OPTS:-} \
  -s "$CI_PROJECT_DIR/.auth/maven-settings.xml" \
  -DskipTests \
  -DaltDeploymentRepository="gitlab-maven::default::$repository" \
  org.apache.maven.plugins:maven-deploy-plugin:3.1.2:deploy
