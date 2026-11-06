SHELL := /bin/bash

IMAGE_NAME ?= zap-dast-pipeline:local
TARGET_URL ?= http://juice-shop:3000
PLAN_FILE  ?= plans/scan-juice-shop.yaml
REPORT_NAME ?= zap-scan-report

.PHONY: help build demo scan scan-graphql shell trivy clean

help: ## Show available Make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

build: ## Build the Dockerized ZAP runner image with pre-installed add-ons
	docker compose build zap-runner

demo: ## Start local OWASP Juice Shop, run authenticated ZAP scan, and output HTML/JSON reports
	docker compose up -d juice-shop
	docker compose run --rm \
		-e TARGET_URL=http://juice-shop:3000 \
		-e PLAN_FILE=plans/scan-juice-shop.yaml \
		-e REPORT_NAME=juice-shop-scan \
		zap-runner
	@echo "Reports written to ./reports/juice-shop-scan.html and ./reports/juice-shop-scan.json"

scan: ## Scan any target URL (e.g., make scan TARGET_URL=https://staging.example.com)
	docker compose run --rm --no-deps \
		-e TARGET_URL="$(TARGET_URL)" \
		-e AUTH_LOGIN_URL="$(AUTH_LOGIN_URL)" \
		-e AUTH_EMAIL="$(AUTH_EMAIL)" \
		-e AUTH_PASSWORD="$(AUTH_PASSWORD)" \
		-e ZAP_AUTH_HEADER_VALUE="$(ZAP_AUTH_HEADER_VALUE)" \
		-e PLAN_FILE="$(PLAN_FILE)" \
		-e REPORT_NAME="$(REPORT_NAME)" \
		-e WEBHOOK_URL="$(WEBHOOK_URL)" \
		zap-runner

scan-graphql: ## Start local DVGA container and run seeded GraphQL DAST scan
	docker compose --profile graphql up -d dvga
	docker compose run --rm --no-deps \
		-e TARGET_URL=http://dvga:5013 \
		-e PLAN_FILE=plans/scan-dvga-graphql.yaml \
		-e REPORT_NAME=dvga-graphql-scan \
		zap-runner

shell: ## Open an interactive bash shell inside the ZAP runner container
	docker compose run --rm --no-deps --entrypoint /bin/bash zap-runner

trivy: build ## Scan the built ZAP runner image with Trivy (HIGH reported, CRITICAL fails)
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy:latest image --severity HIGH --exit-code 0 $(IMAGE_NAME)
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy:latest image --severity CRITICAL --exit-code 1 $(IMAGE_NAME)

clean: ## Stop containers and remove local network
	docker compose --profile graphql down -v --remove-orphans
