FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 PORT=7681

# Base toolbox: shell tools, ssh server, ttyd web terminal, build deps.
# The t64/X/alsa set are the runtime libs the transplanted Hermes chromium
# needs on this Ubuntu base; openssh-client/xz-utils match the official
# hermes image expectations, libolm-dev backs its Matrix adapter.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg git openssh-server ttyd nginx-light tmux \
      vim nano less htop ripgrep jq unzip zip tree procps sudo locales \
      python3 python3-pip python3-venv build-essential \
      iputils-ping dnsutils net-tools \
      openssh-client xz-utils libolm-dev \
      libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 libatspi2.0-0t64 \
      libcairo2 libcups2t64 libdbus-1-3 libdrm2 libgbm1 libglib2.0-0t64 \
      libnspr4 libnss3 libpango-1.0-0 libx11-6 libxcb1 libxcomposite1 \
      libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2 \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends nodejs gh \
  && npm install -g @anthropic-ai/claude-code \
  && npm install -g --ignore-scripts @earendil-works/pi-coding-agent \
  && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh \
  && mkdir -p /run/sshd \
  && sed -i 's/^worker_processes .*/worker_processes 2;/' /etc/nginx/nginx.conf \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Skeleton for the persistent home (the volume mounts empty at /root on first boot).
COPY skel/ /opt/skel/
COPY entrypoint.sh /entrypoint.sh
COPY drop-file-cache /usr/local/bin/drop-file-cache
# The agents menu is installed image-wide so existing volumes (whose /root was
# seeded on first boot) still get menu updates on redeploy.
COPY skel/agents /usr/local/bin/agents
RUN chmod +x /entrypoint.sh /usr/local/bin/agents

# ---------------------------------------------------------------------------
# Hermes (TUI): transplanted from the pinned official image.
# The toolchain under /opt/hermes (venv, pm runtime, chromium, web dist) is
# self-contained, so a plain COPY beats building from source here — the
# Debian-side system symlinks it pointed at are rebuilt below and verified
# at build time, so a broken transplant fails the build loudly instead of
# shipping a dead `hermes` command.
# ---------------------------------------------------------------------------
FROM nousresearch/hermes-agent:v0.22.5 AS hermesdist

FROM base AS final
COPY --from=hermesdist /opt/hermes /opt/hermes
COPY --from=hermesdist /usr/local/lib/libsqlite3.so.* /usr/local/lib/
RUN set -eu; \
    lib="$(find /usr/local/lib -maxdepth 1 -name 'libsqlite3.so.*.*.*' | sort | tail -n 1)"; \
    ln -sf "$(basename "$lib")" /usr/local/lib/libsqlite3.so.0; \
    ln -sf "$(basename "$lib")" /usr/local/lib/libsqlite3.so; \
    printf '/usr/local/lib\n' > /etc/ld.so.conf.d/000-sqlite-fixed.conf; \
    ldconfig; \
    py="$(find /opt/hermes/tools -path '*/bin/python3*' \( -type f -o -type l \) | head -n 1)"; \
    [ -n "$py" ] || { echo 'ERROR: pm python toolchain missing under /opt/hermes/tools' >&2; exit 1; }; \
    ln -sf "$py" /usr/local/bin/python3; \
    /opt/hermes/.venv/bin/python -V; \
    /opt/hermes/.venv/bin/python -c 'import sqlite3; print("venv sqlite", sqlite3.sqlite_version)'; \
    browser="$(find /opt/hermes/tools -type f -name 'chrome' -perm -u+x | head -n 1)"; \
    if [ -n "$browser" ]; then \
      mkdir -p /etc/hermes; \
      printf '%s' "$browser" > /etc/hermes/agent-browser-executable-path; \
    fi; \
    mkdir -p /tmp/hermes-runtime && chmod 0700 /tmp/hermes-runtime; \
    rm -f /opt/hermes/.venv/.lock /opt/hermes/pm-runtime/.lock

# Hermes data lives under /root (the persistent volume) so auth and sessions
# survive redeploys. TUI-only here: gateway mode needs a supervised non-root
# process and belongs to the separate gateway service.
ENV HERMES_HOME=/root/.hermes \
    HERMES_WRITE_SAFE_ROOT=/root \
    HERMES_PYTHON=/opt/hermes/.venv/bin/python \
    HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist \
    HERMES_TUI_DIR=/opt/hermes/ui-tui \
    HERMES_RUNTIME_DIR=/opt/hermes/tools \
    PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/tools \
    XDG_RUNTIME_DIR=/tmp/hermes-runtime
ENV PATH="/opt/hermes/bin:/opt/hermes/.venv/bin:${PATH}"

EXPOSE 22 7681
ENTRYPOINT ["/entrypoint.sh"]
