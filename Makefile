.PHONY: help up down restart relogin build logs login logout token gh-login check update
.DEFAULT_GOAL := help

# Imagem base oficial que o Dockerfile estende (FROM ghcr.io/kirodotdev/kirocrew:stable)
BASE_IMAGE := ghcr.io/kirodotdev/kirocrew:stable

help: ## Mostra esta ajuda (alvos disponíveis)
	@echo "KiroCrew Docker — comandos disponíveis:"; echo; \
	grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: ## Sobe o container
	docker compose up -d

down: ## Para e remove o container
	docker compose down

restart: ## Reinicia o container
	docker compose down && docker compose up -d

relogin: ## Reinicia o container e refaz o login (restart + logout + login)
	docker compose down && docker compose up -d
	docker exec -it kirocrew kiro-cli logout 2>/dev/null || true
	docker exec -it kirocrew kiro-cli login --use-device-flow

build: ## Rebuild da imagem + sobe
	docker compose build && docker compose up -d

check: ## Verifica se há release nova do Kiro Crew (digest remoto x local; não baixa)
	@echo "==> Kiro Crew: comparando digest local x remoto ($(BASE_IMAGE))"; \
	remote=$$(docker manifest inspect -v $(BASE_IMAGE) 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); d=d[0] if isinstance(d,list) else d; print(d.get('Descriptor',{}).get('digest',''))" 2>/dev/null); \
	local=$$(docker image inspect $(BASE_IMAGE) --format '{{index .RepoDigests 0}}' 2>/dev/null | sed 's/.*@//'); \
	if [ -z "$$remote" ]; then echo "    (nao consegui ler o manifest remoto — sem rede/registry?)"; exit 2; fi; \
	if [ -z "$$local" ]; then echo "    base local ausente — rode 'make update' pra baixar."; exit 1; fi; \
	echo "    local:  $$local"; echo "    remoto: $$remote"; \
	if [ "$$remote" = "$$local" ]; then echo "    ✅ atualizado (sem release nova)."; \
	else echo "    ⬆️  UPDATE disponivel — rode 'make update'."; exit 1; fi

update: ## Baixa o stable novo, rebuilda e sobe (estado persiste no volume ./data)
	docker pull $(BASE_IMAGE)
	docker compose build --pull && docker compose up -d
	@echo "==> atualizado. Confira: docker logs kirocrew | tail"

logs: ## Logs em tempo real
	docker compose logs -f

login: ## Login do kiro-cli (device flow)
	docker exec -it kirocrew kiro-cli login --use-device-flow

logout: ## Logout do kiro-cli
	docker exec -it kirocrew kiro-cli logout

token: ## Gera token do dashboard (10 anos)
	docker exec kirocrew kirocrew token --ttl 87600h

gh-login: ## Login do GitHub CLI (gh) dentro do container
	docker exec -it kirocrew gh auth login
