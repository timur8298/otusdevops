# Проектная работа по курсу "DevOps практики и инструменты" на тему Создание процесса непрерывной поставки для приложения с применением практик CI/CD и быстрой обратной связью

# Требования
Автоматизированные процессы создания и управления платформой
Ресурсы Ya.cloud
Инфраструктура для CI/CD
Инфраструктура для сбора обратной связи
Использование практики IaC (Infrastructure as Code) для управления
конфигурацией и инфраструктурой
Настроен процесс CI/CD
Все, что имеет отношение к проекту хранится в Git

# Выполнено
 - Настроен процесс сбора обратной связи
 - Мониторинг (сбор метрик, алертинг, визуализация)
 - Логирование (опционально)
 - ChatOps (опционально)
 - README по работе с репозиторием
 - Описание приложения и его архитектуры
 - How to start?
 - ScreenCast
 - CHANGELOG с описанием выполненной работы

# Описание приложения
Простое микросервисное приложение Search engine. 
Состоит из поискового бота (https://github.com/express42/search_engine_crawler), 
и веб интерфейса к нему (https://github.com/express42/search_engine_ui).
Бот помещает в очередь url переданный ему при запуске. Затем он начинает обрабатывать все url в очереди. Для каждого url бот загружает содержимое страницы, записывая в БД связи между сайтами, между сайтами и словами. Все найденые на странице url помещает обратно в очередь.
Веб-интерфейс минимален, предоставляет пользователю строку для запроса и результаты. Поиск происходит только по индексированным сайтам. Результат содержит только те страницы, на которых были найдены все слова из запроса. Рядом с каждой записью результата отображается оценка полезности ссылки (чем больше, тем лучше). Более подробно можно почитать в файлах Readme в папках src/search_engine_ui и src/search_engine_crawler либо по ссылкам проектов (https://github.com/express42/search_engine_crawler и https://github.com/express42/search_engine_ui)

# Требования к компьютеру, с которого запускается разворачивание инфраструктуры
- Linux OS (WSL)
- git
- curl
- wget
- jq
- yc (https://cloud.yandex.ru/docs/cli/operations/install-cli)
- terraform (https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart)
- Helm v3 (https://helm.sh/ru/docs/intro/install/)

# Установка
Для развертывания инфраструктуры приложения в облаке yandex cloud, нужно скопировать 
в папке terraform terraform.tfvars.example в файл terraform.tfvars
и проставить соответствующие данные в нем.
Для работы с api reg.ru нужно предварительно в настройках кабинета на reg.ru в настройках api указать альтернативный пароль, и прописать диапазон ip адреса/ов с которого будет производится установка.
Запустить start_project.sh в корне проекта (для корректной работы скрипта требуется доступ к репозиторию charts.gitlab.io с ip доступного вне РФ, иначе блокируется)

В результате выполения команды: 
- с помощью terraform:
- в облаке yandex cloud будет развернут кластер k8s (количество нод кластера можно отрегулировать в переменной nodes terraform.tfvars.tf) 
- будет добавлен локально контекст созданного кластера
- установлен с помощью чарта helm, gitlab в созданный кластер
- Получен IP адресс созданного ingress
- Прописан полученный адресс в DNS зоны reg.ru (удалятся все имеющиеся зоны, и полученный адрес пропишется в зоны @ и *)
- После того как DNS зона применится, будет получен пароль для root пользователя gitlab и адрес для входа в gitlab (gitlab.timur8298.ru)
- В гитлабе будет создана группа проекта, и в ней будут добавлены необходимые переменные
- В гитлабе будут созданы проекты (search_engine_ui, search_engine_crawler, search_engine_deploy, monitoring), и произойдет пуш файлов проекта в гитлаб

По ссылке следует авторизоваться по полученным имени и паролю, через GUI в гитлабе добавить агентов 
k8s для всех проектов, и выполнить полученные команды локально чтобы запустить агенты. 
(infrastructure -> Kubernetes clusters -> connect a cluster - > выбрать агент -> скопировать команду и выполнить в терминале.)
Проверить статус агентов. После запушить любой комит в проект search_engine_deploy, monitoring.
В результате в кластере развернется приложение по основному адресу (timur8298.ru). 
(Нужно подождать некоторое время, пока приложение задеплоится, и certmanager получит валидный сертификат lets encrypt)



# Change log
 - Добавил код приложения
 - Добавил докерфайлы для приложения для сборки его в контейнеры
 - Добавил Docker-compose для локального запуска приложения (включил в него поднятие БД mongo и очереди Rabbitmq)
 - С помощью terraform поднял кластер k8s в облаке yandex cloud
 - Развернул приложение в кластере и проверил его работоспособность
 - С помощью terraform и helm настроил поднятие gitlab в кластере
 - Настроил чарты helm для приложения
 - Добавил в чарт деплоя приложения чарты монги и рэббита
 - Добавил деплой инфраструктуры мониторинга и логирования через helm чарт
 - Настроил дашборд в графане
 - Настроил оповещения в телеграмм
 - Добавил автоматическое создание переменных в группе гитлаба, и создание SSH ключа для доступа к гитлабу
 - Добавил автоматическое создание проектов в гитлабе, копирование их в гитлаб
 - Настроил оповещения о деплоях в телеграмм
 - Настроил автоматический деплой кастомного дашборда в графану
