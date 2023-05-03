output "k8s_cluster_public_ip" {
  value = yandex_kubernetes_cluster.testkube.master[0].external_v4_address
}
resource "null_resource" "gitlab_create" {
  depends_on = [yandex_kubernetes_node_group.test-group]
  provisioner "local-exec" {
    command     = <<EOF
      set -e
      #echo "Добавление контекста создаваемого кластера"
      yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.testkube.name} --external --force

      echo "Установка гитлаба с помощью helm в кластер"
      helm upgrade --install gitlab gitlab/gitlab --version 6.11.0 \
        --set global.hosts.domain=${var.project_domain} \
        --set global.edition=ce \
        --set certmanager-issuer.email=semeneevtimur@yandex.ru \
        --set gitlab-runner.runners.privileged=true

      sleep 100
      echo "Получение IP адреса UI gitlab из ingress"
      export GITLAB_IP=$(kubectl get ingress gitlab-webservice-default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      echo $GITLAB_IP
      # Создание Json входных параметров для назначения ресурсных записей reg.ru
      export JSON_A=$(echo '{"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.project_domain}"}],"subdomain":"@","ipaddr":"$GITLAB_IP","output_content_type":"plain"}' | jq -c --arg GITLAB_IP "$GITLAB_IP" '.ipaddr = $GITLAB_IP')
      export JSON_B=$(echo '{"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.project_domain}"}],"subdomain":"*","ipaddr":"$GITLAB_IP","output_content_type":"plain"}' | jq -c --arg GITLAB_IP "$GITLAB_IP" '.ipaddr = $GITLAB_IP')
      
      # Формирование запроса для назначения ресурсных записей reg.ru
      export DNS_A='wget --no-check-certificate -O- -q ''https://api.reg.ru/api/regru2/zone/add_alias?input_data='$JSON_A'&input_format=json'
      export DNS_B='wget --no-check-certificate -O- -q ''https://api.reg.ru/api/regru2/zone/add_alias?input_data='$JSON_B'&input_format=json'

      echo "Вывод DNS зон"
      wget --no-check-certificate -O- -q \
      'https://api.reg.ru/api/regru2/zone/get_resource_records?input_data={"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.project_domain}"}],"output_content_type":"plain"}&input_format=json'

      echo "Очистка ресурсных записей DNS"
      wget --no-check-certificate -O- -q \
      'https://api.reg.ru/api/regru2/zone/clear?input_data={"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.project_domain}"}],"output_content_type":"plain"}&input_format=json'

      echo "Назначение ресурсных записей DNS @ и *"
      $DNS_A
      $DNS_B

      echo "Вывод DNS зон"
      wget --no-check-certificate -O- -q \
      'https://api.reg.ru/api/regru2/zone/get_resource_records?input_data={"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.project_domain}"}],"output_content_type":"plain"}&input_format=json'

      echo "Ждем когда применятся изменения DNS"
      while [[ "$(getent hosts gitlab.${var.project_domain} | awk '{ print $1 }' || true)" != "$GITLAB_IP" ]]
      do
        sleep 5
      done

      echo "Получение пароля root для gitlab"
      GITLAB_PASS="$(kubectl get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d)"
      echo "пароль получен, авторизуйтесь в  gitlab.${var.project_domain} Пользлватель:\n root Пароль:\n $GITLAB_PASS"
    EOF
    interpreter = ["/bin/bash", "-c"]
  }
}
