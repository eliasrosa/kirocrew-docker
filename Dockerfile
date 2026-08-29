FROM ghcr.io/kirodotdev/kirocrew:stable

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    git \
    curl \
    gpg \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian trixie stable" \
       > /etc/apt/sources.list.d/docker.list \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends \
       gh \
       docker-ce-cli \
       ffmpeg \
       nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 986 docker-host 2>/dev/null || true \
    && usermod -aG docker-host kirocrew

# Speech-to-text: faster-whisper (offline, CPU). ffmpeg vem do apt acima.
RUN pip install --no-cache-dir --break-system-packages faster-whisper

# Playwright: CLI (browser automation do KiroCrew) + framework de teste E2E.
# Browsers em /opt (fora de /home/kirocrew, que o volume ./data sobrepoe em runtime),
# com PLAYWRIGHT_BROWSERS_PATH exportado para o runtime encontra-los.
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
# Chrome do Google usa SUID sandbox (chrome-sandbox root:root 4755), invalidado
# pelo user-namespace por-container do runtime Kiro -> aborta. Desliga o sandbox
# do browser (passa --no-sandbox). Trade-off: menos isolamento contra paginas hostis.
ENV PLAYWRIGHT_MCP_SANDBOX=0
RUN npm install -g @playwright/cli @playwright/test \
    && npx --yes playwright install --with-deps chromium chrome \
    && rm -rf /var/lib/apt/lists/*

USER kirocrew

# Atalho: /home/kirocrew/workspace -> caminho real do workspace do KiroCrew.
# Obs: em runtime o volume ./data monta sobre /home/kirocrew; este symlink
# so aparece se o volume nao tiver 'workspace' proprio (ex.: ./data limpo).
RUN ln -sfn /home/kirocrew/.kiro/crew/workspace /home/kirocrew/workspace
