SHELL := /bin/sh

COMPOSE_FILES := -f docker-compose.yml -f docker-compose.generated.yml

DOCKER_REPO ?= luckybill/multi-mitmproxy-service

generate:
	@python3 tools/gen_compose.py

build: generate
	docker compose $(COMPOSE_FILES) build

up: generate
	docker compose $(COMPOSE_FILES) up -d

down:
	docker compose $(COMPOSE_FILES) down

restart: generate
	docker compose $(COMPOSE_FILES) up -d --build

ps:
	docker compose $(COMPOSE_FILES) ps

logs:
	docker compose $(COMPOSE_FILES) logs -f --tail=100

clean:
	rm -f docker-compose.generated.yml

# Generate Argon2id hash for PASSWORD
hash:
	@if [ -z "$(PASSWORD)" ]; then echo "Usage: make hash PASSWORD=yourpass"; exit 1; fi
	@docker run --rm python:3.12-slim sh -lc "pip install -q argon2-cffi && python -c \"from argon2 import PasswordHasher; ph=PasswordHasher(time_cost=3, memory_cost=4096, parallelism=1, hash_len=32); print(ph.hash('$(PASSWORD)'))\""

# Docker Hub helpers
dockerhub-login:
	docker login

dockerhub-build:
	@VCS=$$(git rev-parse --short HEAD || echo unknown); \
	DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
	V=$(VERSION); \
	docker build \
	  --build-arg VERSION=$$V \
	  --build-arg VCS_REF=$$VCS \
	  --build-arg BUILD_DATE=$$DATE \
	  -t $(DOCKER_REPO):latest \
	  -t $(DOCKER_REPO):$$V .

dockerhub-push:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make dockerhub-push VERSION=x.y.z DOCKER_REPO=repo/name"; exit 1; fi
	docker push $(DOCKER_REPO):latest
	docker push $(DOCKER_REPO):$(VERSION)

# 推送镜像到 Docker Hub 
# make dockerhub-build DOCKER_REPO=luckybill/multi-mitmproxy-service VERSION=1.0.2
# make dockerhub-push DOCKER_REPO=luckybill/multi-mitmproxy-service VERSION=1.0.2

# git tag v1.0.2 && git push origin v1.0.2