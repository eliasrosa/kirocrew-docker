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
