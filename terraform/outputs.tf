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
      echo "пароль получен, авторизуйтесь в  gitlab.${var.project_domain} Пользлватель: root Пароль: $GITLAB_PASS"

      echo "добавление токена для root"
      export GITLAB_TOOLBOX=$(kubectl get pod | grep gitlab-toolbox | grep Running | awk '{print $1};')
      kubectl exec $GITLAB_TOOLBOX -- gitlab-rails runner \
        "token = User.find_by_username('root').personal_access_tokens.create(scopes: ['api'], name: 'Automation token'); token.set_token('${var.automation_token}'); token.save!"
      
      echo "Добавление группы в гитлабе"
      export GROUP_ID=$(curl --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        --header "Content-Type: application/json" \
        --data '{"path": "${var.project_group}", "name": "${var.project_group}", "visibility": "public"}' \
        "https://gitlab.${var.project_domain}/api/v4/groups/" | jq '.id')
      echo $GROUP_ID

      echo "Добавление переменных группы"
      curl --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables" --form "key=CI_REGISTRY_USER" --form "value=${var.docker_user}" --form "protected=true"
      curl --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables" --form "key=PROJECT_DOMAIN" --form "value=${var.project_domain}" --form "protected=true" --form "masked=true"
      curl --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables?key=CI_REGISTRY_PASSWORD&masked=true" \
        --header "Content-Type: application/json" --data "{\"value\":\"${var.docker_pass}\"}"

      echo "Добавление ssh открытого ключа"
      curl --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        --header "Content-Type: application/json" \
        --data "{\"key\":\"$(cat ${var.public_key_path_ed})\"}" \
        "https://gitlab.${var.project_domain}/api/v4/user/keys?title=ssh-cert"
    EOF
    interpreter = ["/bin/bash", "-c"]
  }
}
