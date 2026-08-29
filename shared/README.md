# shared/ — compartilhamento host ↔ container

Ponto único para o **host** expor pastas ao agente KiroCrew rodando no container,
sem editar o `docker-compose.yml` a cada projeto.

O compose monta esta pasta em `/home/kirocrew/shared` dentro do container:

```
./shared  (host)  ⇄  /home/kirocrew/shared  (container)
```

O conteúdo é ignorado pelo git — só a pasta, este `README.md` e o `.gitignore`
são versionados.

## Como compartilhar uma pasta do host

Crie um symlink dentro de `shared/` apontando para o diretório do host:

```bash
cd shared
ln -s /caminho/no/host/qualquer-pasta minha-pasta
```

Como o daemon Docker roda no host, o symlink é resolvido no filesystem do host —
o agente passa a ver o conteúdo em `/home/kirocrew/shared/minha-pasta`.

> Também é possível simplesmente copiar/mover arquivos para dentro de `shared/`
> em vez de usar symlink.

Depois de alterar os volumes, recrie o container:

```bash
make down && make up
```
