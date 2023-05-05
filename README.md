# Проектная работа по курсу "DevOps практики и инструменты" на тему Создание процесса непрерывной поставки для приложения с применением Практик CI/CD и быстрой обратной связью

# Требования
Автоматизированные процессы создания и управления платформой
Ресурсы Ya.cloud
Инфраструктура для CI/CD
Инфраструктура для сбора обратной связи
Использование практики IaC (Infrastructure as Code) для управления
конфигурацией и инфраструктурой
Настроен процесс CI/CD
Все, что имеет отношение к проекту хранится в Git

# Чек лист 
[ ] Настроен процесс сбора обратной связи
[ ] Мониторинг (сбор метрик, алертинг, визуализация)
[ ] Логирование (опционально)
[ ] Трейсинг (опционально)
[ ] ChatOps (опционально)
[ ] README по работе с репозиторием
[ ] Описание приложения и его архитектуры
[ ] How to start?
[ ] ScreenCast
[*] CHANGELOG с описанием выполненной работы

# Описание приложения
Простое микросервисное приложение Search engine (https://github.com/express42/search_engine_crawler и https://github.com/express42/search_engine_ui)
Состоит из поискового бота, и веб интерфейса к нему.
Бот помещает в очередь url переданный ему при запуске. Затем он начинает обрабатывать все url в очереди. Для каждого url бот загружает содержимое страницы, записывая в БД связи между сайтами, между сайтами и словами. Все найденые на странице url помещает обратно в очередь.
Веб-интерфейс минимален, предоставляет пользователю строку для запроса и результаты. Поиск происходит только по индексированным сайтам. Результат содержит только те страницы, на которых были найдены все слова из запроса. Рядом с каждой записью результата отображается оценка полезности ссылки (чем больше, тем лучше). Более подробно можно почитать в файлах Readme в папках src/search_engine_ui и src/search_engine_crawler либо по ссылкам проектов (https://github.com/express42/search_engine_crawler и https://github.com/express42/search_engine_ui)

# требования к компьютеру, с которого запускается разворачивание инфраструктуры
- Linux OS (WSL)
- git
- yc (https://cloud.yandex.ru/docs/cli/operations/install-cli)
- terraform (https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart)
- Helm v3 (https://helm.sh/ru/docs/intro/install/)
- wget
- jq
# Установка
Для развертывания инфраструктуры приложения в облаке yandex cloud, нужно скопировать 
в папке terraform terraform.tfvars.example в файл terraform.tfvars
и проставить соответствующие данные в нем.
Запустить terraform apply (для корректной работы скрипта требуется доступ к репозиторию charts.gitlab.io с ip доступного вне РФ, иначе блокируется)
В результате выполения команды: 
- в облаке yandex cloud будет развернут кластер k8s (количество нод кластера можно отрегулировать в секции scale_policy в файле main.tf) 
- будет добавлен локально контекст созданного кластера
- установлен с помощью чарта helm, gitlab в сорзданный кластер
- Получен IP адресс созданного ingress
- Прописан полученный адресс в DNS зоны reg.ru (удалятся все имеющиеся зоны, и полученный адрес пропишется в зоны @ и *)
- После того как DNS зона применится, будет получен пароль для root пользователя gitlab и адрес для входа в gitlab (gitlab.timur8298.ru)

По ссылке следует авторизоваться по полученным имени и паролю, создать в гитлабе группу (timur8298) и три проекта в группе (search_engine_ui, search_engine_crawler, search_engine_deploy). В группе (timur8298) создать переменные CI_REGISTRY_USER и CI_REGISTRY_PASSWORD и проставить в них значения для авторизации в docker registry
Все три проекта (search_engine_ui, search_engine_crawler, search_engine_deploy) с локальными находящимися в папке src.
git init
git remote add origin git@gitlab.timur8298.ru:timur8298/search_engine_%project%.git (подставить по очереди значения проектов вместо %project% )
git add .
git commit -m “init”
git push origin master

Через GUI в гитлабе добавить агентов k8s для всех проектов, и выполнить полученные команды локально чтобы запустить агенты.
Проверить статус агентов. После запушить любой комит в проект search_engine_deploy, в результате в кластере развернется приложение по основному адресу (timur8298.ru). (Нужно подождать некоторое время, пока приложение задеплоится, и certmanager получит валидный сертификат lets encrypt)



# Change log
 - Добавил код приложения
 - Добавил докерфайлы для приложения для сборки его в контейнеры
 - Добавил Docker-compose для локального запуска приложения (включил в него поднятие БД mongo и очереди Rabbitmq)
 - С помощью terraform поднял кластер k8s в облаке yandex cloud
 - Развернул приложение в кластере и проверил его работоспособность
 - С помощью terraform и helm настроил поднятие gitlab в кластере
 - Настроил чарты helm для приложения
 - Добавил в чарт деплоя приложения чарты монги и рэббита
