# Deploy an All-in-One Agent Box on Railway (claude · pi · hermes)

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/claude-code?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=claude-code)

This template gives you an always-on Ubuntu 24.04 workstation with three coding agents pre-installed: [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Pi](https://pi.dev) (`@earendil-works/pi-coding-agent`) and the [Hermes TUI](https://github.com/NousResearch/hermes-agent) (transplanted from the pinned official `nousresearch/hermes-agent` image). Open your Railway domain for a terminal in the browser, or SSH in through Railway's TCP proxy. Your home directory lives on a volume, so repos, agent logins and dotfiles survive every redeploy.

## About Hosting an Agent Box

One service, one volume. The image ships `claude`, `pi`, `hermes`, `git`, `gh`, Node 22, Python 3 + `uv`, `tmux`, `ripgrep`, `jq`, `vim`, build tools and an OpenSSH server. A `ttyd` web terminal (basic-auth gated) and `sshd` (password or key) both drop you into the same `tmux` session, so you can start a long agent run from your laptop and pick it up from your phone. SSH host keys are stored on the volume, so your client never sees a "host key changed" warning after a redeploy.

Each agent keeps its state on the volume: `~/.claude`, `~/.pi/agent` and `~/.hermes` — logins, sessions and settings all persist across redeploys.

## Common Use Cases

- Run Claude Code, Pi or Hermes 24/7 without keeping your laptop open
- Code from an iPad, Chromebook or phone: the browser terminal needs no SSH client
- Pick the right agent per task: `claude` for Anthropic-native work, `pi` for a minimal terminal harness, `hermes` for multi-provider work
- A disposable root box with a stable IP for scripts, scraping, cron-style jobs or CI debugging

## Dependencies

- None. Single service, no database.

### Deployment Dependencies

- [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code)
- [Pi](https://github.com/earendil-works/pi)
- [Hermes Agent](https://github.com/NousResearch/hermes-agent)
- [ttyd](https://github.com/tsl0922/ttyd) web terminal
- [GitHub CLI](https://cli.github.com/)

### Implementation Details

**First use:** open your Railway domain, log in with `WEB_USER` and the generated `WEB_PASSWORD` (service Variables tab). Run `agents` to pick an agent, or launch one directly:

- `claude` — complete `/login` by pasting the URL into a browser, or set `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or `ANTHROPIC_API_KEY` as a variable so it is signed in from the start
- `pi` — run `/login` inside Pi, or set a provider key variable
- `hermes` — run `hermes setup` to choose a provider (Nous Portal, Anthropic, OpenRouter, …), or set a provider key variable

Provider keys set as service variables (`ANTHROPIC_*`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `GLM_API_KEY`, `DEEPSEEK_API_KEY`, `KIMI_*`, …) are exported into SSH login shells automatically, so `claude`, `pi` and `hermes` all see them the moment you connect.

**Handy commands inside the box:**

- `agents` — menu that launches the chosen agent inside a tmux window (survives disconnects)
- `cl` — Claude Code inside a detachable `tmux` session named `claude`; `tmux attach -t claude` resumes it
- `gh auth login` or set `GH_TOKEN` to push to GitHub
- `claude update`, `pi update` and `hermes update` upgrade each agent in place

**SSH:** Railway creates a TCP proxy for port 22 on deploy. Copy the host and port from Settings → Networking and run `ssh root@<host> -p <port>` with `ROOT_PASSWORD`, or add your public key to `AUTHORIZED_KEYS` and clear `ROOT_PASSWORD` for key-only login.

## Optional Second Service: Always-On Hermes Gateway

The box runs Hermes as an interactive TUI. For **gateway mode** — talking to Hermes from Telegram, Discord or Slack around the clock — deploy a second Railway service from this repo:

- **Dockerfile:** `hermes.dockerfile` — rides the official `nousresearch/hermes-agent` image, pinned to `v0.22.5` (override via the `HERMES_IMAGE_VERSION` build arg; legacy source builds from a `HERMES_GIT_REF` are still supported)
- **Start:** `scripts/entrypoint.sh` validates platform tokens, writes runtime env into `HERMES_HOME`, then execs `hermes gateway run` (re-executing via `gosu` when it lands as root, since upstream refuses to run the gateway as root)
- **Volume:** mount a Railway volume at `/data`; the entrypoint keeps `/data/.hermes` owned by the unprivileged `hermes` user without walking the whole volume at boot
- **Variables:** set at least one platform token (`TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`, or `SLACK_BOT_TOKEN` + `SLACK_APP_TOKEN`) — the service refuses to start without one, and defaults to deny-all unless you configure `*_ALLOWED_USERS`

Notes and limits:

- You are root in the box. Anything you install outside `/root` disappears on redeploy; anything under `/root` stays.
- Give the box service at least 2 GB of RAM: it carries Chromium (Hermes), plus two local CLIs. The gateway service is lighter but still wants ≥ 1 GB.
- There is no Docker daemon inside the box.
- The web terminal password is the whole security model for a root shell. Keep it strong and do not share the URL.

## Why Deploy an Agent Box on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying an agent box on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, AI agents, and more on Railway.
