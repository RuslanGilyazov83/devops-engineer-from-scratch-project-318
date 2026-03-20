ANSIBLE_DIR         = ansible
INVENTORY           = inventory/hosts.yml
PLAYBOOK_SETUP      = playbooks/setup.yml
PLAYBOOK_DEPLOY     = playbooks/deploy.yml
PLAYBOOK_MONITORING = playbooks/monitoring.yml

.PHONY: help ansible-deps setup deploy monitoring-setup check-metrics check-nginx check-logs lint test ansible-test smoke code-setup

# Hexlet project-action ожидает target code-setup и requirements.yml в корне
code-setup: ## Установка зависимостей для проверки Hexlet
	@if command -v ansible-galaxy >/dev/null 2>&1; then \
		ansible-galaxy collection install -r requirements.yml; \
	else \
		echo "ansible-galaxy not found, skipping"; \
	fi

help: ## Показать список доступных команд
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Ansible ────────────────────────────────────────────────────────────────

ansible-deps: ## Установить зависимости Ansible
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml

setup: ## Подготовить сервер: установить Docker
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) $(PLAYBOOK_SETUP) --ask-vault-pass

deploy: ## Развернуть приложение на сервере
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DEPLOY) --ask-vault-pass

monitoring-setup: ## Развернуть Prometheus, Loki, Grafana на сервере мониторинга
	cd $(ANSIBLE_DIR) && ansible-playbook -i $(INVENTORY) $(PLAYBOOK_MONITORING) --ask-vault-pass

# ─── Lint и тесты ────────────────────────────────────────────────────────────

lint: ## Проверить плейбуки ansible-lint
	cd $(ANSIBLE_DIR) && ansible-lint .

test: ansible-test ## Алиас для ansible-test (требование задания 8)

ansible-test: ## Smoke-тест Ansible: ping хостов, проверка доступности
	cd $(ANSIBLE_DIR) && ansible all -i $(INVENTORY) -m ping --ask-vault-pass

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
	@echo "Запись тестового лога — логи в Docker volume, использовать docker exec (см. README)"
	@echo "Через 30 сек проверьте в Grafana: Explore -> Loki -> {job=\"nginx\"} | json | uri=\"/test-e2e\""
