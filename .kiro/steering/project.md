---
inclusion: auto
name: kirocrew-docker
description: Use ao trabalhar neste repo (kirocrew-docker) — editar o Dockerfile/compose, montar volumes, reiniciar o container, ajustar o ambiente do agente, ou diagnosticar problemas de mount/rede. Triggers: kirocrew-docker, compose, Dockerfile, volume, mount, make build, make restart, .env, KIROCREW_DEV, KIROCREW_SSH, shared, seccomp, sandbox.
---

# kirocrew-docker — contexto para o agente

Infra que roda o KiroCrew headless em Docker. Repo **público e genérico**:
não referenciar projetos pessoais, caminhos de usuário reais, IPs ou nomes de
host aqui — usar variáveis de ambiente e exemplos genéricos.

O `README.md` cobre setup e comandos para o **usuário**. Este arquivo cobre os
gotchas para o **agente** que roda dentro do container.

## Contexto de execução do agente

O agente que edita **este repo** roda na **IDE do host** (Kiro IDE), não dentro
do container kirocrew. Consequências:

- Pode rodar `make restart`, `make relogin`, `make down`, `make build` etc.
  sem risco de se desconectar — esses comandos afetam o container kirocrew,
  não o processo do agente.
- O container kirocrew é um **serviço separado** gerenciado pelo agente via
  Docker CLI do host.
- Só proibir esses comandos se o agente estiver explicitamente rodando
  **dentro** do container (ex: sessão KiroCrew headless via Telegram/dashboard).

## O agente RODA dentro do container que este repo define

Consequências diretas:

- **`make down` / `make restart` / `make relogin` NÃO podem ser rodados pelo agente
  quando ele está rodando DENTRO do container `kirocrew`.** `make down` para e
  remove o container — o agente se desconecta no meio. Qualquer reinício é do
  **usuário, no host**.
- **Exceção:** quando o agente roda na IDE do host (ex: Kiro IDE), pode rodar
  `make restart` e `make relogin` normalmente — ele não está no container.
- **`./data` é montado em `/home/kirocrew`** (o home inteiro do agente, estado
  persistente: sessões, memória, config). Mover ou mexer no `data/` com o
  container de pé arrisca o vínculo desse estado — só com o container parado.

## Mount: o source de `-v`/volume é resolvido no HOST

Quem interpreta o source de um bind-mount é o **daemon**, no filesystem dele —
não o shell/processo que monta. Como o agente vive num container, um caminho que
só existe dentro do container **não existe para o daemon**, e o Docker cria um
**diretório vazio** no lugar, sem erro.

Regras que saem disso:

- Volumes do compose que apontam para caminhos do host devem usar **caminho
  absoluto do host** (via variável) ou ser **path-espelhado** (mesmo caminho dos
  dois lados). Caminho de container como source vira lixo vazio.
- `KIROCREW_DEV` monta o diretório de projetos do host **path-espelhado**
  (`${KIROCREW_DEV}:${KIROCREW_DEV}`): o caminho é idêntico dentro e fora, então
  o agente edita os repos reais E consegue rodar `docker compose` a partir deles
  (os volumes relativos dos projetos resolvem, porque o PWD que o processo vê é o
  que o daemon vê). É por isso que é path-espelhado e não `:/algum/outro/lugar`.
- `docker build` e `docker cp` NÃO sofrem disso — o contexto/arquivo trafega pelo
  socket. Só bind-mount (`-v`, volumes do compose) é resolvido no host.

## Config sem vazar dado pessoal

Caminhos pessoais entram por **variável no `.env`** (gitignored), com exemplo
genérico `/home/YOUR_USER/...` no `.env.example` (versionado). Padrão já usado
por `KIROCREW_SSH` e `KIROCREW_DEV`. Fallback `${VAR:-/dev/null}` desativa um
mount opcional quando a variável não está definida.

## Diagnóstico antes de tentar fix de container

Antes de qualquer tentativa de fix envolvendo kernel, namespaces, capabilities
ou mounts dentro de um container, **testar primeiro com `docker run --rm`**
descartável:

```bash
docker run --rm \
  --security-opt seccomp:./kirocrew-seccomp.json \
  --cap-add SYS_ADMIN \
  --entrypoint /bin/sh \
  ghcr.io/kirodotdev/kirocrew:stable \
  -c "<comando a testar>"
```

Isso evita ciclos de `make restart` com configs quebradas. A regra:
- 1ª tentativa falhou → testar hipótese com `docker run --rm` antes de editar
  o compose e reiniciar.
- Nunca fazer 3+ iterações de restart sem validar a hipótese de forma isolada.

Antes de sobrescrever `entrypoint` no compose, **sempre ler o script original**:

```bash
docker run --rm --entrypoint="" ghcr.io/kirodotdev/kirocrew:stable \
  cat $(docker run --rm --entrypoint="" ghcr.io/kirodotdev/kirocrew:stable which kirocrew-entrypoint)
```

Ou mais simples:

```bash
docker run --rm --entrypoint="" ghcr.io/kirodotdev/kirocrew:stable \
  cat /usr/local/bin/kirocrew-entrypoint
```

O entrypoint original faz scrub de credenciais, probe de sandbox e chama `tini`.
Sobrescrever sem ler quebra o container silenciosamente (`init process is not running`).

## Persistência do login

O token de autenticação do kiro-cli é salvo em:
```
./data/.local/share/kiro-cli/data.sqlite3  (tabela auth_kv, key: kirocli:social:token)
```

Como `./data` é o volume persistente montado em `/home/kirocrew`, o **login
persiste entre restarts** — não é necessário refazer o login a cada `make restart`.

O `make relogin` verifica automaticamente via `kiro-cli whoami` antes de pedir
login. Só inicia o device flow se o token estiver ausente ou expirado.

**Sessão OAuth expirada** — `kiro-cli whoami` retorna "Logged in" mas o agente
recebe `"Your session has expired. Run kiro-cli login"`. Isso acontece quando o
token OAuth do lado da AWS/Kiro expira (independe de restart ou build), então o
`whoami` sozinho NÃO detecta. Solução:
```bash
make logout && make login
```

O que causa `"not logged in"` nos logs **não é perda de token**, mas race
condition no boot: o gateway tenta spawnar o kiro-cli imediatamente ao subir, e
se o processo ainda não estiver pronto retorna rc=1 e entra em cooldown de 1800s.
Solução: após o boot, aguardar ~10s antes de fazer qualquer chamada, ou usar
`make relogin` que já lida com isso.

## Fluxo após update ou restart

O token persiste — `make relogin` verifica antes de pedir novo login. Usar sempre
`make relogin` ao invés de `docker restart kirocrew`:

```bash
make relogin   # restart + verifica login (só pede device flow se necessário)
```

Nunca usar `docker restart kirocrew` isolado — reinicia sem verificar o login e
pode deixar o gateway em cooldown de 1800s se houver race condition no boot.

## Fluxo de mudança neste repo

Acumular ajustes na working tree mostrando os diffs; o **usuário** builda/testa
no host (`make build` / `make restart`); só no fim, após o ok dele, juntar num
PR e mergear via `gh`. Não abrir um PR por ajuste, não rodar `make build` (é do
usuário). Push direto na `main` é bloqueado — usar feature branch + PR + merge.

## Rede

- Containers do host só resolvem por hostname se o `kirocrew` estiver nas mesmas
  redes Docker (DNS é por-rede); por IP já alcança via bridge. Conectar às redes
  de projetos pessoais NÃO deve constar no compose deste repo.
- A LAN do host é alcançável por roteamento da bridge, sem config extra.

## Sandbox

O kiro-cli 2.21+ usa sandbox interno baseado em Linux user namespaces
(`unshare(CLONE_NEWUSER+NEWNS)` + `mount --make-rprivate /`). Dentro de
containers Docker o rootfs é montado com propagação `shared` pelo daemon — o
kernel bloqueia `mount --make-rprivate` dentro de user namespaces filhos mesmo
com `CAP_SYS_ADMIN`, porque os mounts foram criados fora daquele user namespace.

**Solução adotada: `privileged: true` no compose.** É a única forma de garantir
que os processos filhos (agente, apps file-explorer/md-notebook) consigam
manipular a propagação. O `seccomp` e `AppArmor` nativos do Docker são
desabilitados por `--privileged`, mas o isolamento de filesystem/rede/PID
permanece.

Diagnóstico rápido de sandbox:
```bash
docker exec kirocrew python3 -c "from kiro_crew.sandbox import detect_backend; print(detect_backend())"
# deve retornar "namespace" — se retornar "none", o sandbox está desabilitado
```

Após update de imagem que quebre o sandbox: rodar `make relogin` (restart + re-auth).
O erro típico nos logs é:
```
sandbox: BLOCKED -- making mount propagation private on / failed: errno 13
```
