external_url ENV.fetch("GITLAB_EXTERNAL_URL", "http://gitlab.localhost:8080")
registry_external_url ENV.fetch("GITLAB_REGISTRY_EXTERNAL_URL", "http://registry.localhost:5050")

gitlab_rails["gitlab_shell_ssh_port"] = ENV.fetch("GITLAB_SSH_PORT", "2222").to_i
gitlab_rails["packages_enabled"] = true
gitlab_rails["registry_enabled"] = true
gitlab_rails["gitlab_default_projects_features_container_registry"] = true
gitlab_rails["time_zone"] = "UTC"

registry["enable"] = true
registry_nginx["enable"] = true
registry_nginx["listen_port"] = 5050
registry_nginx["listen_https"] = false

nginx["listen_port"] = 80
nginx["listen_https"] = false
nginx["redirect_http_to_https"] = false
letsencrypt["enable"] = false

prometheus_monitoring["enable"] = true
postgresql["shared_buffers"] = "256MB"
gitlab_rails["env"] = {
  "MALLOC_ARENA_MAX" => "2",
  "RUBY_GC_HEAP_GROWTH_FACTOR" => "1.03",
}
