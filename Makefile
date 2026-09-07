.PHONY: up down restart build logs login logout token gh-login check update

# Imagem base oficial que o Dockerfile estende (FROM ghcr.io/kirodotdev/kirocrew:stable)
BASE_IMAGE := ghcr.io/kirodotdev/kirocrew:stable

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

build:
	docker compose build && docker compose up -d

# check: há release nova do Kiro Crew? Compara o digest do `stable` REMOTO
# com o da imagem base já baixada localmente. Não baixa nada (só lê o manifest
# remoto). Sai com código 0 se está atualizado, 1 se há update disponível.
check:
	@echo "==> Kiro Crew: comparando digest local x remoto ($(BASE_IMAGE))"; \
	remote=$$(docker manifest inspect -v $(BASE_IMAGE) 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); d=d[0] if isinstance(d,list) else d; print(d.get('Descriptor',{}).get('digest',''))" 2>/dev/null); \
	local=$$(docker image inspect $(BASE_IMAGE) --format '{{index .RepoDigests 0}}' 2>/dev/null | sed 's/.*@//'); \
	if [ -z "$$remote" ]; then echo "    (nao consegui ler o manifest remoto — sem rede/registry?)"; exit 2; fi; \
	if [ -z "$$local" ]; then echo "    base local ausente — rode 'make update' pra baixar."; exit 1; fi; \
	echo "    local:  $$local"; echo "    remoto: $$remote"; \
	if [ "$$remote" = "$$local" ]; then echo "    ✅ atualizado (sem release nova)."; \
	else echo "    ⬆️  UPDATE disponivel — rode 'make update'."; exit 1; fi

# update: baixa a base `stable` mais nova, rebuilda a imagem estendida e sobe.
# O estado persiste no volume ./data (upgrade não perde dados).
update:
	docker pull $(BASE_IMAGE)
	docker compose build --pull && docker compose up -d
	@echo "==> atualizado. Confira: docker logs kirocrew | tail"

logs:
	docker compose logs -f

login:
	docker exec -it kirocrew kiro-cli login --use-device-flow

logout:
	docker exec -it kirocrew kiro-cli logout

token:
	docker exec kirocrew kirocrew token --ttl 87600h

gh-login:
	docker exec -it kirocrew gh auth login
