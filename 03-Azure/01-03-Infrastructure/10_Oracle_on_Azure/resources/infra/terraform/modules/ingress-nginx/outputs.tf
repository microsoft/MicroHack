output "release_name" {
  value = helm_release.nginx_quick.name
}

output "namespace" {
  value = helm_release.nginx_quick.namespace
}
