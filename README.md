# KiroCrew Docker

Docker setup para rodar o [KiroCrew](https://github.com/kirodotdev/KiroCrew) headless
com suporte a SSH (acesso ao GitHub), `gh` CLI, Docker CLI e sandbox via seccomp.

A imagem também é um **ambiente de desenvolvimento completo** para o agente trabalhar
diretamente nos projetos montados, incluindo:

- **Node.js 24 + npm** (via NodeSource)
- **Python 3.12** + `faster-whisper` (speech-to-text offline, CPU)
- **Docker CLI + Docker Compose nativo** (`docker-compose-plugin`)
- **Toolchain C/C++**: `build-essential` (gcc/g++/make) + `cmake`
- **ffmpeg** (via apt)
- **Playwright** (`@playwright/cli` + `@playwright/test`) com Chromium/Chrome

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

# 5. Login do GitHub CLI (opcional)
make gh-login

# 6. Gerar token do dashboard
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
| `make logout` | Logout do kiro-cli |
| `make token` | Gera token do dashboard (10 anos) |
| `make gh-login` | Login do GitHub CLI (`gh`) dentro do container |

## Estrutura

```
kirocrew-docker/
├── data/                   # Estado persistente (gitignore)
├── .env                    # Vars locais (gitignore)
├── .env.example            # Template de configuração
├── .gitignore
├── Dockerfile              # Imagem base + dev-env (Node 24, Python 3.12, Docker CLI+compose, toolchain C/C++, ffmpeg, Playwright)
├── docker-compose.yml
├── kirocrew-seccomp.json   # Seccomp profile para sandbox
├── shared/                 # Compartilhamento host ↔ container (conteúdo no gitignore)
└── Makefile
```

## Volumes

| Host | Container | Modo |
|------|-----------|------|
| `./data` | `/home/kirocrew` | rw — estado persistente |
| `KIROCREW_SSH` | `/home/kirocrew/.ssh` | ro — chave SSH |
| `/var/run/docker.sock` | `/var/run/docker.sock` | rw — Docker do host |
| `./shared` | `/home/kirocrew/shared` | rw — compartilhamento host ↔ container (veja `shared/README.md`) |
| `KIROCREW_DEV` | `KIROCREW_DEV` (mesmo caminho) | rw — diretório de projetos do host, path-espelhado (opcional; vazio desativa) |

## Acesso ao Docker do host

O container monta o socket `/var/run/docker.sock`, permitindo que o agente KiroCrew gerencie containers diretamente no host via `docker` CLI.

> ⚠️ **Atenção:** montar o socket Docker equivale a acesso root no host. Use com consciência — qualquer agente rodando dentro do KiroCrew terá controle total sobre os containers do host.

O `docker-ce-cli` é instalado na imagem e o usuário `kirocrew` é adicionado ao grupo com o GID do grupo `docker` do host (configurado no Dockerfile).

## Sandbox

O setup usa o [seccomp profile oficial](https://github.com/kirodotdev/KiroCrew/blob/main/docker/seccomp/kirocrew-seccomp.json) do KiroCrew, que habilita o sandbox de namespace sem precisar de `--privileged`.

## Atualizar

```bash
docker compose pull
make build
```
