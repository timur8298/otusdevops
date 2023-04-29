output "k8s_cluster_public_ip" {
  value = yandex_kubernetes_cluster.testkube.master[0].external_v4_address
}
resource "null_resource" "gitlab" {
  depends_on = [yandex_kubernetes_node_group.test-group]
  provisioner "local-exec" {
    command     = <<EOF
      set -e
      echo "Добавление контекста создаваемого кластера"
      yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.testkube.name} --external --force
      
      echo "Установка гитлаба с помощью helm в кластер"
      helm upgrade --install gitlab gitlab/gitlab --version 6.11.0 \
        --set global.hosts.domain=timur8298.ru \
        --set global.edition=ce \
        --set certmanager-issuer.email=semeneevtimur@yandex.ru \
        --set gitlab-runner.runners.privileged=true
    EOF
    interpreter = ["/bin/bash", "-c"]
  }
}
