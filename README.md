### Hexlet tests and linter status:
[![Actions Status](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions)
[![CI](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml/badge.svg)](https://github.com/RuslanGilyazov83/devops-engineer-from-scratch-project-318/actions/workflows/ci.yml)

# DevOps Engineer from Scratch — Проект 318

Доска объявлений на Spring Boot + React Admin, развёрнутая в Yandex Cloud.

Исходное приложение: [hexlet-components/project-devops-deploy](https://github.com/hexlet-components/project-devops-deploy)

## Адрес сервера

```
http://158.160.223.121:8080
```

## Эндпоинты

| Путь | Описание |
|------|----------|
| `GET /api/bulletins` | Список объявлений |
| `GET /swagger-ui/index.html` | Swagger UI |
| `GET /actuator/health` | Проверка работоспособности (порт 9090) |
| `GET /actuator/health/liveness` | Liveness проба |
| `GET /actuator/health/readiness` | Readiness проба |

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

| Файл | Назначение |
|------|------------|
| `ansible/setup.yml` | Установка Docker на сервер |
| `ansible/deploy.yml` | Запуск PostgreSQL и приложения |
| `ansible/inventory/hosts.yml` | Список серверов |
| `ansible/group_vars/all.yml` | Общие переменные |
| `ansible/roles/docker/` | Роль — установка Docker |
| `ansible/roles/db_postgres/` | Роль — запуск PostgreSQL в Docker |
| `ansible/roles/app/` | Роль — запуск контейнера приложения |

## Makefile-команды

```bash
make help          # Показать все команды

make build         # Собрать JAR
make test          # Прогнать тесты
make run           # Запустить локально (dev профиль)

make docker-build  # Собрать Docker-образ локально
make docker-run    # Запустить образ локально

make ansible-deps  # Установить зависимости Ansible
make setup         # Подготовить сервер (установить Docker)
make deploy        # Развернуть приложение
```

## Деплой на сервер

```bash
# 1. Установить зависимости Ansible
make ansible-deps

# 2. Прописать IP сервера в ansible/inventory/hosts.yml

# 3. Создать файл с секретами
ansible-vault create ansible/group_vars/vault.yml

# 4. Подготовить сервер
make setup

# 5. Развернуть приложение
make deploy
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
```
