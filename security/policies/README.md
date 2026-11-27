This directory contains the security acceptance policy used by the GitLab
pipeline. Exceptions in `trivy-exceptions.yaml` are an audit register only;
Trivy does not consume it automatically. To suppress a finding, add its exact
ID to `security/trivy/.trivyignore` only after recording the owner, reason,
target, and expiry in the exception register.
