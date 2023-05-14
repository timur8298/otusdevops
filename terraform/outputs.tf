output "k8s_cluster_public_ip" {
  value = yandex_kubernetes_cluster.testkube.master[0].external_v4_address
}
resource "null_resource" "gitlab_create" {
  depends_on = [yandex_kubernetes_node_group.test-group]
  provisioner "local-exec" {
    command     = <<EOF
      set -e
      echo "Добавление контекста создаваемого кластера"
      yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.testkube.name} --external --force

      echo "Установка гитлаба с помощью helm в кластер"
      helm repo add gitlab https://charts.gitlab.io/
      helm upgrade --install gitlab gitlab/gitlab --version 6.11.3 \
        --set global.hosts.domain=${var.project_domain} \
        --set global.edition=ce \
        --set certmanager-issuer.email=${var.project_email} \
        --set gitlab-runner.runners.privileged=true

      #sleep 100
      echo "Получение IP адреса UI gitlab из ingress"
      export GITLAB_IP=$(kubectl get ingress gitlab-webservice-default -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      echo $GITLAB_IP
      echo "Создание Json входных параметров для назначения ресурсных записей reg.ru"
      export JSON_A=$(echo '{"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.regru_main}"}],"subdomain":"@","ipaddr":"$GITLAB_IP","output_content_type":"plain"}' | jq -c --arg GITLAB_IP "$GITLAB_IP" '.ipaddr = $GITLAB_IP')
      export JSON_B=$(echo '{"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.regru_main}"}],"subdomain":"*","ipaddr":"$GITLAB_IP","output_content_type":"plain"}' | jq -c --arg GITLAB_IP "$GITLAB_IP" '.ipaddr = $GITLAB_IP')
      
      echo "Формирование запроса для назначения ресурсных записей reg.ru"
      export DNS_A='wget --no-check-certificate -O- -q ''https://api.reg.ru/api/regru2/zone/add_alias?input_data='$JSON_A'&input_format=json'
      export DNS_B='wget --no-check-certificate -O- -q ''https://api.reg.ru/api/regru2/zone/add_alias?input_data='$JSON_B'&input_format=json'

      #echo "Вывод DNS зон"
      #wget --no-check-certificate -O- -q \
      #'https://api.reg.ru/api/regru2/zone/get_resource_records?input_data={"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.regru_main}"}],"output_content_type":"plain"}&input_format=json'

      echo "Очистка ресурсных записей DNS"
      wget --no-check-certificate -O- -q \
      'https://api.reg.ru/api/regru2/zone/clear?input_data={"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.regru_main}"}],"output_content_type":"plain"}&input_format=json'

      echo "Назначение ресурсных записей DNS @ и *"
      $DNS_A
      $DNS_B

      echo "Вывод DNS зон"
      wget --no-check-certificate -O- -q \
      'https://api.reg.ru/api/regru2/zone/get_resource_records?input_data={"username":"${var.dns_account}","password":"${var.dns_password}","domains":[{"dname":"${var.regru_main}"}],"output_content_type":"plain"}&input_format=json'

      echo "Ждем когда применятся изменения DNS"
      while [[ "$(getent hosts gitlab.${var.project_domain} | awk '{ print $1 }' || true)" != "$GITLAB_IP" ]]
      do
        sleep 5
      done

      echo "Получение пароля root для gitlab"
      GITLAB_PASS="$(kubectl get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d)"

      echo "добавление токена для root"
      export GITLAB_TOOLBOX=$(kubectl get pod | grep gitlab-toolbox | grep Running | awk '{print $1};')
      kubectl exec $GITLAB_TOOLBOX -- gitlab-rails runner \
        "token = User.find_by_username('root').personal_access_tokens.create(scopes: ['api'], name: 'Automation token'); token.set_token('${var.automation_token}'); token.save!"
      
      echo "Добавление группы в гитлабе"
      export GROUP_ID=$(curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        --header "Content-Type: application/json" \
        --data '{"path": "${var.project_group}", "name": "${var.project_group}", "visibility": "public"}' \
        "https://gitlab.${var.project_domain}/api/v4/groups/" | jq '.id')
      echo $GROUP_ID

      echo "Добавление переменных группы"
      curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables" --form "key=CI_REGISTRY_USER" --form "value=${var.docker_user}" --form "protected=true"
      curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables" --form "key=PROJECT_DOMAIN" --form "value=${var.project_domain}" --form "protected=true" --form "masked=true"
      curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables?key=CI_REGISTRY_PASSWORD&masked=true&protected=true" \
        --header "Content-Type: application/json" --data "{\"value\":\"${var.docker_pass}\"}"
      curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables?key=TELEGRAM_BOT_TOKEN&masked=true&protected=true" \
        --header "Content-Type: application/json" --data "{\"value\":\"${var.telegramm_bot_token}\"}"
      curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/variables?key=TELEGRAM_CHAT_ID&masked=true" \
        --header "Content-Type: application/json" --data "{\"value\":\"${var.telegram_chat_id}\"}"

      echo "Добавление ssh открытого ключа"
      curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        --header "Content-Type: application/json" \
        --data "{\"key\":\"$(cat ${var.public_key_path_ed})\"}" \
        "https://gitlab.${var.project_domain}/api/v4/user/keys?title=ssh-cert"
      ssh-keygen -f "$(realpath -P ~/.ssh/known_hosts)" -R "gitlab.${var.project_domain}" 2>/dev/null

      echo "Создание проектов в группе ${var.project_group}"
      export SRC_PATH=$(realpath -P ../src)
      for PROJECT in search_engine_ui search_engine_crawler search_engine_deploy monitoring
      do
        curl --insecure --request POST --header "PRIVATE-TOKEN: ${var.automation_token}" \
        "https://gitlab.${var.project_domain}/api/v4/groups/$GROUP_ID/projects" --form "name=$PROJECT" --form "path=$PROJECT" --form "namespace_id=$GROUP_ID" --form "initialize_with_readme=false"

        cd $SRC_PATH/$PROJECT
        rm -rf ./.git
        git init
        git remote add origin git@gitlab.${var.project_domain}:${var.project_group}/$PROJECT.git
        git add .
        git checkout -b master
        git commit -m "init"
        GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git push --set-upstream origin master
      done

      echo -e "https://gitlab.${var.project_domain} \nПользлватель: root \nПароль: $GITLAB_PASS"

    EOF
    interpreter = ["/bin/bash", "-c"]
  }
}
