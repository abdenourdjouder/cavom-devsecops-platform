# CI/CD security policy

- Jobs use pinned container versions. Dependency updates must be reviewed in a pull or merge request.
- Trivy dependency, secret, configuration, and built-image scans gate publication on HIGH or CRITICAL findings. Unfixed findings are suppressed because no source upgrade is available; `trivy` artifacts retain JSON and SARIF evidence.
- CycloneDX SBOMs are generated for both OCI image archives before publication.
- Sonar uses `sonar.qualitygate.wait=true`; a failed or timed-out server-side Quality Gate fails the pipeline.
- Maven and container publication use the short-lived `CI_JOB_TOKEN`. Authentication material is created with private permissions and removed after use.
- `production` must be configured as a protected GitLab environment. Only protected branches/tags may receive its protected variables.
- `KUBE_CONFIG_BASE64` must contain a base64-encoded, least-privilege service-account kubeconfig and be protected and masked. It is decoded only in the deploy job and removed on exit.
- Security-relevant pipeline changes require security-code-owner review.
