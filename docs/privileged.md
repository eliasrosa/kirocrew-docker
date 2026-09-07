# Por que usamos `privileged: true` e quais são os riscos

## Contexto

O kiro-cli 2.21+ usa um mecanismo de isolamento interno chamado **sandbox de
namespace**. O objetivo é isolar cada subprocesso do agente (ferramentas, buscas,
execuções de código) para que um subprocesso comprometido não consiga ler
credenciais ou arquivos do agente principal.

Para isso, o kiro-cli faz três operações no Linux:

1. `unshare(CLONE_NEWUSER)` — cria um novo "usuário virtual" para o processo filho
2. `unshare(CLONE_NEWNS)` — cria um novo namespace de filesystem para o filho
3. `mount --make-rprivate /` — torna o filesystem do filho privado (mudanças não
   vazam para o pai)

## O problema dentro de containers Docker

O Docker monta o filesystem raiz do container com propagação `shared` — uma
política de kernel que permite que mudanças de mount se propaguem entre namespaces.

O passo 3 (tornar o filesystem privado) falha com `errno 13 (Permission denied)`
porque o kernel bloqueia essa operação quando os mounts foram criados **fora** do
user namespace que está tentando modificá-los. Isso vale mesmo com
`CAP_SYS_ADMIN` explícito — a restrição é intencional no design do kernel Linux.

O erro nos logs é:
```
sandbox: BLOCKED -- making mount propagation private on / failed: errno 13
```

## O que `privileged: true` faz

`privileged: true` equivale a rodar o container com:
- Todas as capabilities do Linux ativas (incluindo `CAP_SYS_ADMIN`)
- Sem filtro de syscalls (seccomp desabilitado)
- Sem perfil AppArmor
- Acesso de leitura/escrita em `/sys` e `/proc` do host

Em termos práticos: um processo dentro do container tem acesso ao mesmo nível
de um processo root no host.

## O que continua isolado

Mesmo com `privileged: true`, o Docker mantém:

- **Namespace de PID** — processos dentro não enxergam processos do host
- **Namespace de rede** — rede isolada (bridge Docker), sem acesso direto à
  interface de rede do host
- **Namespace de UTS** — hostname separado
- **Filesystem por camadas** — o container ainda tem seu próprio overlay
  filesystem; mudanças não persistem fora dos volumes montados

## Riscos concretos

| Risco | Descrição | Mitigação neste setup |
|-------|-----------|----------------------|
| Escape de container | Um processo malicioso pode usar syscalls privilegiadas para sair do container e acessar o host | O agente KiroCrew tem controle sobre o que executa; não roda código arbitrário de fontes não confiáveis |
| Acesso ao kernel do host | Pode carregar módulos, modificar parâmetros via `/proc/sys`, usar `ptrace` em qualquer processo | Aceitável dado que o socket Docker (`/var/run/docker.sock`) já concede controle root sobre o host |
| Acesso a devices do host | `/dev` do host fica acessível | Nenhuma — é uma consequência de `privileged` |
| Seccomp desabilitado | Syscalls normalmente bloqueadas pelo Docker ficam disponíveis | O sandbox interno do kiro-cli reintroduz isolamento em nível de subprocesso |

## Por que aceitamos esse risco

O risco incremental de `privileged: true` neste setup é **baixo** porque:

1. **O socket Docker já está montado.** Montar `/var/run/docker.sock` já concede
   controle root sobre o host via API Docker — qualquer processo dentro do
   container pode criar um container `--privileged` novo ou montar qualquer
   diretório do host. `privileged: true` não adiciona uma superfície de ataque
   que o socket Docker já não abria.

2. **O container não é exposto à internet.** A porta `5476` só escuta em
   `127.0.0.1` (localhost). Acesso externo requer autenticação via token.

3. **O agente tem controle sobre o que executa.** O KiroCrew não executa código
   arbitrário recebido de fontes externas sem aprovação.

## Alternativas exploradas

| Alternativa | Por que não funcionou |
|-------------|----------------------|
| `cap_add: SYS_ADMIN` | A capability existe no conjunto efetivo, mas o kernel ainda bloqueia `mount --make-rprivate` em mounts criados fora do user namespace |
| `security_opt: seccomp=./kirocrew-seccomp.json` | O seccomp libera os syscalls necessários, mas o bloqueio é de política de namespace, não de syscall |
| `sandbox: off` no config do KiroCrew | Desabilita o sandbox do agente principal, mas os apps internos (`file-explorer`, `md-notebook`) usam `mode="standard"` hardcoded e continuam falhando |
| `mount --make-rslave /` no entrypoint | Funciona como root, mas os processos filhos ainda falham porque herdam os mounts do container (criados pelo daemon fora do user namespace) |

## Como reverter (se necessário)

Se uma versão futura do kiro-cli ou do Docker resolver o problema sem
`privileged`, basta:

1. Remover `privileged: true` do `docker-compose.yml`
2. Descomentar `security_opt` com o seccomp profile
3. Rodar `make relogin`
4. Verificar: `docker exec kirocrew python3 -c "from kiro_crew.sandbox import detect_backend; print(detect_backend())"`
   — deve retornar `namespace`
