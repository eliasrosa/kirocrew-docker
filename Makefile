.PHONY: up down restart build logs login logout token gh-login

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down && docker compose up -d

build:
	docker compose build --no-cache && docker compose up -d

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
