#!/bin/bash
set -e

# /root is a Railway volume: empty on first boot, root-owned. Seed dotfiles once
# (flag file, not per-file checks: local docker pre-copies the image's /root into a
# fresh volume, which would otherwise shadow our skel).
if [ ! -f /root/.claude-box-seeded ]; then
  cp -af /opt/skel/. /root/ && touch /root/.claude-box-seeded
fi
# Volumes seeded before .profile was in skel: login shells (SSH, tmux) never read ~/.bashrc.
[ -f /root/.profile ] || cp /opt/skel/.profile /root/
mkdir -p /root/.ssh /root/src && chmod 700 /root/.ssh

# Persist SSH host keys on the volume so clients don't see "host key changed" after redeploys.
mkdir -p /root/.ssh-host
for t in rsa ed25519; do
  [ -f "/root/.ssh-host/ssh_host_${t}_key" ] || ssh-keygen -q -t "$t" -N '' -f "/root/.ssh-host/ssh_host_${t}_key"
  cp -f "/root/.ssh-host/ssh_host_${t}_key" "/root/.ssh-host/ssh_host_${t}_key.pub" /etc/ssh/
  chmod 600 "/etc/ssh/ssh_host_${t}_key"
done

# Root login: password from ROOT_PASSWORD, optional keys from AUTHORIZED_KEYS.
[ -n "${ROOT_PASSWORD:-}" ] && echo "root:${ROOT_PASSWORD}" | chpasswd
[ -n "${AUTHORIZED_KEYS:-}" ] && printf '%s\n' "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
cat > /etc/ssh/sshd_config.d/railway.conf <<CFG
Port 22
ListenAddress 0.0.0.0
ListenAddress ::
PermitRootLogin yes
PasswordAuthentication $([ -n "${ROOT_PASSWORD:-}" ] && echo yes || echo no)
ClientAliveInterval 60
CFG
/usr/sbin/sshd

# Make service variables visible to SSH sessions too (sshd strips the environment).
# Covers the provider keys claude/pi/hermes all read from the environment.
env | grep -E '^(ANTHROPIC_|CLAUDE_|GH_TOKEN|GITHUB_TOKEN|TZ|PORT|OPENAI_API_KEY|OPENROUTER_API_KEY|GEMINI_API_KEY|GOOGLE_API_KEY|XAI_API_KEY|DEEPSEEK_API_KEY|DASHSCOPE_API_KEY|KIMI_|GLM_API_KEY|ZAI_API_KEY|HF_TOKEN|MISTRAL_API_KEY|GROQ_API_KEY|TOGETHER_API_KEY|CEREBRAS_API_KEY|MINIMAX_API_KEY|OPENCODE_ZEN_API_KEY)' | sed 's/^/export /; s/=/="/; s/$/"/' > /etc/profile.d/railway-env.sh || true

# nginx on $PORT: unauthenticated /healthcheck for Railway, everything else to ttyd.
cat > /etc/nginx/sites-enabled/default <<CFG
server {
  listen ${PORT} default_server;
  listen [::]:${PORT} default_server;
  location = /healthcheck { return 200 "ok"; }
  location / {
    proxy_pass http://127.0.0.1:7682;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_read_timeout 1d;
  }
}
CFG
nginx

# Railway counts the kernel's cache of files this container has touched as the
# service's memory, and with no memory pressure it is never freed: one npm
# install shows as hundreds of MB. Drop it for the home volume every 15 min.
( while sleep 900; do nice -n 19 drop-file-cache /root /tmp || true; done ) &

echo "== claude-box ready: web terminal on :${PORT}, sshd on :22, claude $(claude --version 2>/dev/null)"
# Web terminal: ttyd with basic auth, each tab attaches to the same tmux session.
exec ttyd -i 127.0.0.1 -p 7682 -W -c "${WEB_USER:-admin}:${WEB_PASSWORD:?WEB_PASSWORD is required}" \
  -t titleFixed="claude-box" -t fontSize=14 \
  bash -lc 'exec tmux new -A -s main'
