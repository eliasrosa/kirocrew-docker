# KiroCrew Docker

Docker setup para rodar o [KiroCrew](https://github.com/kirodotdev/KiroCrew) headless com suporte a SSH (acesso ao GitHub) e sandbox via seccomp.

## Pré-requisitos

- Docker + Docker Compose
- `make`
- Chave SSH configurada em `~/.ssh`

## Setup

```bash
# 1. Clonar o repo
git clone git@github.com:eliasrosa/kirocrew-docker.git
cd kirocrew-docker

# 2. Configurar variáveis
cp .env.example .env
# Editar .env com o path correto do seu .ssh

# 3. Build e subir
make build

# 4. Login do kiro-cli
make login

# 5. Gerar token do dashboard
make token
# Abrir o link impresso em http://localhost:5476/?token=...
```

## Comandos

| Comando | Ação |
|---------|------|
| `make up` | Sobe o container |
| `make down` | Para e remove |
| `make restart` | Reinicia |
| `make build` | Rebuild da imagem + sobe |
| `make logs` | Logs em tempo real |
| `make login` | Login do kiro-cli (device flow) |
| `make token` | Gera token do dashboard (10 anos) |
| `make gh-login` | Login do GitHub CLI (`gh`) dentro do container |

## Estrutura

```
kirocrew-docker/
├── data/                   # Estado persistente (gitignore)
├── .env                    # Vars locais (gitignore)
├── .env.example            # Template de configuração
├── .gitignore
├── Dockerfile              # Imagem base + openssh-client + git
├── docker-compose.yml
├── kirocrew-seccomp.json   # Seccomp profile para sandbox
└── Makefile
```

## Volumes

| Host | Container | Modo |
|------|-----------|------|
| `./data` | `/home/kirocrew` | rw — estado persistente |
| `KIROCREW_SSH` | `/home/kirocrew/.ssh` | ro — chave SSH |

## Sandbox

O setup usa o [seccomp profile oficial](https://github.com/kirodotdev/KiroCrew/blob/main/docker/seccomp/kirocrew-seccomp.json) do KiroCrew, que habilita o sandbox de namespace sem precisar de `--privileged`.

## Atualizar

```bash
docker compose pull
make build
```
