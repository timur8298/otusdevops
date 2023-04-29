output "k8s_cluster_public_ip" {
  value = yandex_kubernetes_cluster.testkube.master[0].external_v4_address
}

