ANSIBLE_DIR         = ansible
INVENTORY           = $(ANSIBLE_DIR)/inventory/hosts.yml
PLAYBOOK_SETUP      = $(ANSIBLE_DIR)/setup.yml
PLAYBOOK_DEPLOY     = $(ANSIBLE_DIR)/deploy.yml
PLAYBOOK_MONITORING = $(ANSIBLE_DIR)/monitoring.yml

IMAGE_NAME ?= ruslangilyazov/project-devops-deploy
IMAGE_TAG  ?= dev

.PHONY: help build test run docker-build docker-run ansible-deps setup deploy monitoring-setup check-metrics check-nginx check-logs lint ansible-test smoke

help: ## Показать список доступных команд
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Сборка и тесты ─────────────────────────────────────────────────────────

build: ## Собрать JAR
	./gradlew bootJar --no-daemon

test: ## Прогнать тесты
	./gradlew test --no-daemon

run: ## Запустить локально (dev профиль, H2 БД)
	./gradlew bootRun --no-daemon

# ─── Docker (локально) ──────────────────────────────────────────────────────

docker-build: ## Собрать Docker-образ локально
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run: ## Запустить образ локально
	docker run --rm -p 8080:8080 -p 9090:9090 $(IMAGE_NAME):$(IMAGE_TAG)

# ─── Ansible ────────────────────────────────────────────────────────────────

ansible-deps: ## Установить зависимости Ansible
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml

setup: ## Подготовить сервер: установить Docker
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_SETUP)

deploy: ## Развернуть приложение на сервере
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DEPLOY) --ask-vault-pass

monitoring-setup: ## Развернуть Prometheus, Loki, Grafana на сервере мониторинга
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_MONITORING) --ask-vault-pass

# ─── Lint и тесты ────────────────────────────────────────────────────────────

lint: ## Проверить плейбуки ansible-lint
	ansible-lint $(ANSIBLE_DIR)/

ansible-test: ## Smoke-тест Ansible: ping хостов, проверка доступности
	ansible all -i $(INVENTORY) -m ping

smoke: ## Smoke-тест: curl к приложению, Prometheus health, Grafana
	@echo "=== App: health ==="
	@curl -sf --connect-timeout 5 http://$(APP_HOST)/actuator/health || (echo "FAIL: App health" && exit 1)
	@echo ""
	@echo "=== App: static/REST (bulletins) ==="
	@curl -sf --connect-timeout 5 -o /dev/null -w "%{http_code}" http://$(APP_HOST)/api/bulletins && echo " OK" || (echo "FAIL" && exit 1)
	@echo ""
	@echo "=== Prometheus: targets ==="
	@curl -sf --connect-timeout 5 "http://$(MONITORING_HOST):9090/api/v1/targets" | head -c 200 && echo "..." || (echo "FAIL: Prometheus" && exit 1)
	@echo ""
	@echo "=== Grafana: login page ==="
	@curl -sf --connect-timeout 5 -o /dev/null -w "%{http_code}" http://$(MONITORING_HOST):3000/login && echo " OK" || (echo "FAIL: Grafana" && exit 1)
	@echo ""
	@echo "Smoke test passed."

# ─── Проверка метрик ────────────────────────────────────────────────────────

APP_HOST ?= 158.160.223.121

check-metrics: ## Проверить health и метрики приложения через Nginx
	@echo "=== Health ==="
	curl -s http://$(APP_HOST)/actuator/health | python3 -m json.tool || curl -s http://$(APP_HOST)/actuator/health
	@echo ""
	@echo "=== Prometheus metrics (первые 20 строк) ==="
	curl -s http://$(APP_HOST)/actuator/prometheus | head -20

MONITORING_HOST ?= 93.77.187.78

check-nginx: ## Проверить stub_status и nginx-exporter
	@echo "=== Nginx metrics (nginx-exporter, порт 9113) ==="
	curl -s http://$(APP_HOST):9113/metrics | grep -E "nginx_(up|connections|http_requests)" | head -15

check-logs: ## End-to-end: записать тест-лог, проверить Loki (см. README)
	@echo "Запись тестового лога на app-сервер..."
	@echo "Выполните вручную:"
	@echo "  ssh ... yc-user@$(APP_HOST) \"echo '{\\\"time\\\":\\\"\$$(date -Iseconds)\\\",\\\"status\\\":999,\\\"uri\\\":\\\"/test-e2e\\\",\\\"method\\\":\\\"GET\\\"}' >> /var/log/nginx/app-access.log\""
	@echo "Через 30 сек проверьте в Grafana: Explore -> Loki -> {job=\"nginx\"} | json | uri=\"/test-e2e\""
