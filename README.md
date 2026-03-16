### Hexlet tests and linter status:
[![Actions Status](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions)
[![CI](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml/badge.svg)](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml)

# DevOps Engineer from Scratch — Проект 318

Доска объявлений на Spring Boot + React Admin, развёрнутая в Yandex Cloud.

Исходное приложение: [hexlet-components/project-devops-deploy](https://github.com/hexlet-components/project-devops-deploy)

## Адрес сервера

```
http://158.160.223.121
```

## Эндпоинты приложения

| Путь | Порт | Описание |
|------|------|----------|
| `GET /api/bulletins` | 80 (Nginx) | Список объявлений |
| `GET /swagger-ui/index.html` | 80 (Nginx) | Swagger UI |
| `GET /actuator/health` | 80 (Nginx) | Состояние приложения (через Nginx) |
| `GET /actuator/health/liveness` | 80 (Nginx) | Liveness проба |
| `GET /actuator/health/readiness` | 80 (Nginx) | Readiness проба |
| `GET /actuator/prometheus` | 80 (Nginx) | Метрики Prometheus (через Nginx) |
| `GET /stub_status` | 80 (Nginx) | Nginx stub_status (только localhost и сервер мониторинга) |

> Management-порт `9090` доступен только с localhost — Nginx проксирует его наружу.

## Метрики

### Метрики хоста (Node Exporter, порт 9100)

Node Exporter работает как systemd-сервис, слушает только на localhost:9100.
Доступ открывается только с сервера мониторинга (Security Group).

| Метрика | Описание |
|---------|----------|
| `node_load1` | Средняя нагрузка CPU за 1 минуту |
| `node_load5` | Средняя нагрузка CPU за 5 минут |
| `node_cpu_seconds_total` | Суммарное время CPU по режимам (user/system/idle) |
| `node_memory_MemAvailable_bytes` | Доступная оперативная память |
| `node_memory_MemTotal_bytes` | Всего оперативной памяти |
| `node_filesystem_avail_bytes` | Свободное место на диске |
| `node_filesystem_size_bytes` | Размер файловой системы |
| `node_disk_read_bytes_total` | Прочитано байт с диска |
| `node_disk_written_bytes_total` | Записано байт на диск |
| `node_network_receive_bytes_total` | Получено байт по сети |
| `node_network_transmit_bytes_total` | Отправлено байт по сети |
| `node_procs_running` | Количество запущенных процессов |
| `node_systemd_unit_state` | Состояние systemd-сервисов |

### Метрики приложения (Spring Actuator / Micrometer)

| Метрика | Описание |
|---------|----------|
| `process_uptime_seconds` | Время работы JVM-процесса |
| `process_cpu_usage` | Использование CPU процессом |
| `jvm_memory_used_bytes` | Используемая память JVM |
| `jvm_memory_max_bytes` | Максимальная память JVM |
| `jvm_gc_pause_seconds_count` | Количество пауз GC |
| `http_server_requests_seconds_count` | Количество HTTP-запросов |
| `http_server_requests_seconds_sum` | Суммарное время обработки запросов |
| `hikaricp_connections_active` | Активных соединений с БД |
| `hikaricp_connections_idle` | Свободных соединений в пуле |
| `spring_data_repository_invocations_seconds_count` | Количество запросов к БД |

## Команды проверки метрик

```bash
# Health приложения через Nginx
curl http://158.160.223.121/actuator/health

# Метрики Prometheus через Nginx
curl http://158.160.223.121/actuator/prometheus

# Health напрямую на management-порту (только с сервера)
curl http://localhost:9090/actuator/health

# Метрики Node Exporter (только с сервера)
curl http://localhost:9100/metrics

# Конкретные метрики Node Exporter
curl -s http://localhost:9100/metrics | grep node_load1
curl -s http://localhost:9100/metrics | grep node_memory_MemAvailable
curl -s http://localhost:9100/metrics | grep node_filesystem_avail

# Метрики приложения — HTTP-запросы
curl -s http://158.160.223.121/actuator/prometheus | grep http_server_requests

# stub_status Nginx (только с app-сервера или с IP мониторинга)
curl http://127.0.0.1/stub_status
# или с app-сервера: curl http://158.160.223.121/stub_status
# (доступ ограничен: 127.0.0.1 и IP сервера мониторинга)

# Метрики nginx-prometheus-exporter (порт 9113, доступ с сервера мониторинга)
# Нужно открыть TCP 9113 в Security Group app-сервера для IP мониторинга (93.77.187.78)
curl -s http://158.160.223.121:9113/metrics | grep nginx_

# Логи Nginx в JSON
sudo tail -f /var/log/nginx/app-access.log
```

## Логи: Promtail + Loki

Promtail на app-сервере собирает логи Docker-контейнеров и Nginx, отправляет в Loki на сервере мониторинга.

> **Security Group**: откройте TCP 3100 на сервере мониторинга (93.77.187.78) для IP app-сервера (158.160.223.121).

### Лейблы для фильтрации

| Лейбл | Значение |
|-------|----------|
| `job` | docker, nginx |
| `logtype` | access, error |
| `env` | prod |
| `app` | bulletins |
| `host` | hostname сервера |

### LogQL-запросы (Grafana Explore или дашборд Logs)

```
# Все access-логи Nginx
{job="nginx", logtype="access"}

# Ошибки 5xx
{job="nginx", logtype="access"} | json | status >= 500

# Latency > 1s
{job="nginx", logtype="access"} | json | request_time > 1

# Поиск по IP/строке
{job=~"nginx|docker"} |~ "158.160"
```

### End-to-end проверка

```bash
# 1. Записать тестовую строку в лог на app-сервере (нужен sudo)
ssh -i ~/.ssh/id_ed25519 yc-user@158.160.223.121 \
  "echo '{\"time\":\"$(date -Iseconds)\",\"status\":999,\"uri\":\"/test-e2e\",\"method\":\"GET\"}' | sudo tee -a /var/log/nginx/app-access.log"

# 2. Подождать 10–30 секунд (Promtail батчит отправку)

# 3. Проверить в Grafana: Explore → Loki → режим Code → запрос:
#    {job="nginx"} | json | uri="/test-e2e"
#    Открыть http://93.77.187.78:3000/explore, выбрать Loki
```

## Grafana

```
http://93.77.187.78:3000
```

| Параметр | Значение |
|----------|----------|
| Логин | `admin` |
| Пароль | задаётся через `ansible-vault` (`grafana_admin_password`) |

### Дашборды

| Дашборд | Описание |
|---------|----------|
| [Status Page](http://93.77.187.78:3000/d/status-page) | Сводная страница состояния всех сервисов |
| [Logs](http://93.77.187.78:3000/d/logs) | Логи Nginx/Docker, 5xx, latency, поиск |
| [Nginx](http://93.77.187.78:3000/d/nginx) | RPS, соединения, коды ответов, latency |
| [System Resources](http://93.77.187.78:3000/d/system-resources) | CPU, память, диск, сеть, load average |
| [Spring App](http://93.77.187.78:3000/d/spring-app) | HTTP-запросы, JVM, коды ответов, пул БД |

### Datasources

| Источник | URL | Статус |
|----------|-----|--------|
| Prometheus | `http://prometheus:9090` | Активен |
| Loki | `http://loki:3100` | Активен |

## Алертинг

### Contact Point — Telegram

Уведомления приходят в Telegram-бот. Токены хранятся в Vault.

| Переменная Vault | Описание |
|------------------|----------|
| `telegram_bot_token` | Токен бота от @BotFather |
| `telegram_chat_id` | ID чата или группы (числовое значение) |

#### Как создать Telegram-бот (пошагово)

1. Откройте Telegram, найдите `@BotFather`
2. Отправьте `/newbot`, задайте имя и username
3. Скопируйте токен вида `1234567890:AABBCCddEEFF...`
4. Создайте группу или откройте личный чат с ботом, отправьте `/start`
5. Узнайте chat_id:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | python3 -m json.tool | grep '"id"'
   ```
6. Добавьте в vault.yml:
   ```bash
   ansible-vault edit ansible/group_vars/all/vault.yml
   ```
   ```yaml
   telegram_bot_token: "1234567890:AABBCCddEEFF..."
   telegram_chat_id: "-1001234567890"
   ```

### Alert Rules

Правила хранятся в `ansible/roles/grafana/files/provisioning/alerting/alert-rules.yml`.
Разворачиваются той же командой, что и дашборды: `make monitoring-setup`.

| Правило | Метрика | Порог | for |
|---------|---------|-------|-----|
| Сервис недоступен | `up == 0` | < 1 | 1m |
| Высокая нагрузка CPU | `node_cpu_seconds_total` | > 80% | 5m |
| Высокое использование памяти | `node_memory_MemAvailable_bytes` | > 85% | 5m |
| Мало места на диске | `node_filesystem_avail_bytes` | < 15% | 5m |
| Высокий процент ошибок 5xx | `http_server_requests_seconds_count` | > 5% | 5m |

### Где смотреть алерты в Grafana

- **Все правила**: `http://93.77.187.78:3000/alerting/list`
- **Contact points**: `http://93.77.187.78:3000/alerting/notifications`
- **Активные алерты**: `http://93.77.187.78:3000/alerting/alerts`
- **Status Page дашборд**: `http://93.77.187.78:3000/d/status-page`
- **Nginx дашборд** (RPS, коды ответов, 5xx): `http://93.77.187.78:3000/d/nginx`
- **Logs дашборд** (LogQL, 5xx, latency): `http://93.77.187.78:3000/d/logs`
- **Alert по логам** (всплеск 5xx): Grafana → Alerting → правило «Всплеск 5xx в логах Nginx»

### Как триггернуть тестовый алерт вручную

**Через UI (рекомендуется):**
1. Grafana → Alerting → Alert rules
2. Выберите правило (например, «Сервис недоступен» или «Всплеск 5xx в логах Nginx»)
3. Нажмите «⋯» → **Send test alert**

**Через API (для автоматизации):**
```bash
curl -X POST http://93.77.187.78:3000/api/alertmanager/grafana/api/v2/alerts \
  -H "Content-Type: application/json" \
  -u "admin:YOUR_GRAFANA_PASSWORD" \
  -d '[{"labels":{"alertname":"TestAlert","severity":"critical"},"annotations":{"summary":"Тестовое уведомление"}}]'
```

> Пароль Grafana берётся из Vault (`grafana_admin_password`).

## Сервер мониторинга (Prometheus)

```
http://93.77.187.78:9090
```

| Путь | Описание |
|------|----------|
| `http://93.77.187.78:9090/graph` | Prometheus UI — запросы и графики |
| `http://93.77.187.78:9090/targets` | Состояние всех таргетов (up == 1) |
| `http://93.77.187.78:9090/alerts` | Активные алерты |

### Проверка таргетов

```bash
# Проверить что все таргеты в состоянии UP
curl -s http://93.77.187.78:9090/api/v1/targets | python3 -m json.tool | grep '"health"'

# Запросить конкретную метрику
curl -s 'http://93.77.187.78:9090/api/v1/query?query=up' | python3 -m json.tool
```

## Ручная проверка (для приёмки)

Проверяющий должен убедиться:

| Проверка | Команда / действие |
|----------|-------------------|
| Обе машины доступны | `make ansible-test` — ping хостов |
| Приложение отдаёт REST | `curl http://158.160.223.121/api/bulletins` |
| Приложение — статика | `curl -I http://158.160.223.121/` |
| Grafana показывает метрики | Открыть http://93.77.187.78:3000 → дашборд System Resources |
| Grafana показывает логи (Loki) | Explore → Loki → `{job="nginx"}` |
| Алерты можно задёргать | Alerting → Alert rules → Send test alert |

Скриншоты дашбордов (при необходимости) — в `__data__/assets/`.

---

## Порты и доступность

| Порт | Сервер | Сервис | Доступность |
|------|--------|--------|-------------|
| 80 | app | Nginx reverse proxy | Публично |
| 8080 | app | Spring Boot app | Только localhost (через Nginx) |
| 9090 | app | Spring Actuator (management) | Только localhost (через Nginx) |
| 9100 | app | Node Exporter | Только сервер мониторинга |
| 9113 | app | nginx-prometheus-exporter | Только сервер мониторинга |
| 9080 | app | Promtail (внутренний) | Только localhost |
| 9090 | monitoring | Prometheus | Публично (для проверки проекта) |
| 3000 | monitoring | Grafana | Публично |
| 3100 | monitoring | Loki | Только app-сервер (158.160.223.121) |

## Быстрый старт (локально)

```bash
# Запустить с профилем dev (H2 in-memory БД, без PostgreSQL)
make run

# Или в Docker
make docker-build
make docker-run
```

Приложение доступно на `http://localhost:8080`, Actuator на `http://localhost:9090`.

## Инфраструктура (Yandex Cloud)

| Компонент | Сервис |
|-----------|--------|
| Виртуальная машина | Yandex Compute Cloud — Ubuntu 22.04 |
| База данных | Yandex Managed Service for PostgreSQL 15 |
| Объектное хранилище | Yandex Object Storage (S3-совместимое) |
| Сеть | Yandex Virtual Private Cloud |

## Docker-образ

```
ruslangilyazov/project-devops-deploy:latest
```

Собирается автоматически при push в `main` через GitHub Actions.

## Ansible-плейбуки

Все файлы находятся в директории [`ansible/`](ansible/).

| Файл / Директория | Назначение |
|-------------------|------------|
| `ansible/setup.yml` | Установка Docker (все серверы) |
| `ansible/deploy.yml` | Запуск сервисов на app-сервере (БД, приложение, Node Exporter, Nginx) |
| `ansible/monitoring.yml` | Запуск Prometheus, Loki, Grafana на сервере мониторинга |
| `ansible/inventory/hosts.yml` | Список серверов (группы `app` и `monitoring`) |
| `ansible/group_vars/all/vars.yml` | Общие переменные (таргеты Prometheus, версии) |
| `ansible/group_vars/all/vault.yml` | Секретные переменные (зашифрованы) |
| `ansible/group_vars/monitoring/vars.yml` | Параметры Prometheus |
| `ansible/roles/docker/` | Установка Docker |
| `ansible/roles/db_postgres/` | PostgreSQL в Docker |
| `ansible/roles/app/` | Контейнер приложения |
| `ansible/roles/node_exporter/` | Node Exporter как systemd-сервис |
| `ansible/roles/nginx_proxy/` | Nginx с JSON-логами, stub_status и проброс actuator |
| `ansible/roles/nginx_exporter/` | nginx-prometheus-exporter (systemd, порт 9113) |
| `ansible/roles/promtail/` | Promtail — сбор логов в Loki |
| `ansible/roles/loki/` | Loki в Docker на сервере мониторинга |
| `ansible/roles/prometheus/` | Prometheus в Docker с конфигом и алертами |
| `ansible/roles/grafana/` | Grafana в Docker с provisioning datasources, дашбордами и алертингом |
| `ansible/roles/grafana/files/provisioning/alerting/alert-rules.yml` | Правила алертинга (5 правил) |
| `ansible/roles/grafana/files/provisioning/alerting/notification-policies.yml` | Маршрутизация уведомлений |
| `ansible/roles/grafana/templates/provisioning/alerting/contact-points.yml.j2` | Telegram contact point (секреты из Vault) |

## Makefile-команды

```bash
make help          # Показать все команды

make build         # Собрать JAR
make test          # Прогнать тесты
make run           # Запустить локально (dev профиль)

make docker-build  # Собрать Docker-образ локально
make docker-run    # Запустить образ локально

make ansible-deps       # Установить зависимости Ansible
make setup              # Установить Docker (все серверы)
make deploy             # Развернуть приложение + Promtail (app-сервер)
make monitoring-setup   # Развернуть Prometheus, Loki, Grafana (сервер мониторинга)

make lint          # ansible-lint: проверить плейбуки
make ansible-test  # Smoke: ping всех хостов
make smoke         # Smoke: curl к приложению, Prometheus, Grafana
```

> Для `make lint` нужен ansible-lint: `pip install ansible-lint`. Лучше запускать на Linux/WSL (на Windows возможны ошибки из‑за зависимости `grp`). В CI ansible-lint выполняется автоматически.

## Развёртывание с нуля (полная процедура)

Ниже — пошаговая инструкция для развёртывания обеих ВМ с нуля.

### 1. Подготовка ключей и окружения

```bash
# Убедитесь, что есть SSH-ключ (например Ed25519)
ls -la ~/.ssh/id_ed25519

# Если нет — создайте
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519 -N ""
```

Добавьте публичный ключ (`~/.ssh/id_ed25519.pub`) в Yandex Cloud при создании ВМ (или через консоль → Compute Cloud → ВМ → SSH-ключи).

### 2. Создание ВМ в Yandex Cloud

1. **App-сервер**: Ubuntu 22.04, минимум 2 vCPU, 2 GB RAM. Публичный IP.
2. **Monitoring-сервер**: Ubuntu 22.04, 2 vCPU, 2 GB RAM. Публичный IP.
3. Настройте Security Groups (см. [Порты и доступность](#порты-и-доступность)).

### 3. Fork и клонирование

```bash
git clone https://github.com/<your-username>/devops-engineer-from-scratch-project-318.git
cd devops-engineer-from-scratch-project-318
```

### 4. Переменные Vault

Создайте зашифрованный файл с секретами:

```bash
ansible-vault create ansible/group_vars/all/vault.yml
```

Вставьте (замените значения на свои):

```yaml
postgres_db: appdb
postgres_user: appuser
postgres_password: YOUR_SECURE_PASSWORD
s3_bucket: your-bucket-name
s3_region: ru-central1
s3_endpoint: https://storage.yandexcloud.net
s3_access_key: YOUR_ACCESS_KEY
s3_secret_key: YOUR_SECRET_KEY
grafana_admin_password: YOUR_GRAFANA_PASSWORD
telegram_bot_token: "1234567890:AABBCCddEEFF..."
telegram_chat_id: "-1001234567890"
```

Сохранение: `:wq` (vim) или Ctrl+S (другие редакторы). Введите пароль Vault при сохранении.

### 5. Inventory

Отредактируйте `ansible/inventory/hosts.yml` — укажите IP ваших ВМ и SSH-пользователя:

```yaml
app:
  hosts:
    app_server:
      ansible_host: <APP_SERVER_IP>
      ansible_user: ubuntu   # или yc-user
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519

monitoring:
  hosts:
    monitoring_server:
      ansible_host: <MONITORING_SERVER_IP>
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
```

Обновите `ansible/group_vars/all/vars.yml`: `app_server_host` и `monitoring_server_ip`.

### 6. Запуск плейбуков

```bash
# Установить зависимости Ansible
make ansible-deps

# Подготовить обе машины (Docker)
make setup

# Развернуть приложение на app-сервере
make deploy

# Развернуть Prometheus, Loki, Grafana на monitoring-сервере
make monitoring-setup
```

При каждом `make deploy` и `make monitoring-setup` будет запрашиваться пароль Vault (`--ask-vault-pass`).

### 7. Проверка домена и мониторинга

```bash
# Приложение
curl http://<APP_IP>/actuator/health
curl http://<APP_IP>/api/bulletins

# Prometheus
curl http://<MONITORING_IP>:9090/-/healthy

# Grafana
open http://<MONITORING_IP>:3000   # логин admin, пароль из Vault

# Smoke-тест (все проверки одной командой)
make smoke APP_HOST=<APP_IP> MONITORING_HOST=<MONITORING_IP>
```

### 8. Переменные окружения (опционально)

Для CI/CD или скриптов можно задать IP через переменные:

```bash
export APP_HOST=158.160.223.121
export MONITORING_HOST=93.77.187.78
make smoke
```

---

## Справка: IP, URL, порты, уведомления

| Параметр | Значение |
|----------|----------|
| **App-сервер** | 158.160.223.121 |
| **Monitoring-сервер** | 93.77.187.78 |
| **Приложение** | http://158.160.223.121 |
| **Grafana** | http://93.77.187.78:3000 |
| **Prometheus** | http://93.77.187.78:9090 |
| **Loki** | http://93.77.187.78:3100 (внутри сети) |
| **Уведомления** | Telegram (токен и chat_id в Vault) |

Полная таблица портов — см. [Порты и доступность](#порты-и-доступность).

---

## Деплой на сервер (кратко)

```bash
# 1. Установить зависимости Ansible
make ansible-deps

# 2. Прописать IP сервера в ansible/inventory/hosts.yml (уже сделано)

# 3. Создать файл с секретами (если ещё не создан)
ansible-vault create ansible/group_vars/all/vault.yml

# 4. Подготовить сервер
make setup

# 5. Развернуть приложение
make deploy

# 6. Развернуть мониторинг (на отдельном сервере)
make monitoring-setup
```

### Секреты в vault.yml

```yaml
postgres_db: appdb
postgres_user: appuser
postgres_password: your_password
s3_bucket: your-bucket-name
s3_region: ru-central1
s3_endpoint: https://storage.yandexcloud.net
s3_access_key: your_access_key
s3_secret_key: your_secret_key
grafana_admin_password: your_grafana_password
telegram_bot_token: "1234567890:AABBCCddEEFF..."
telegram_chat_id: "-1001234567890"
```
