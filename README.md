# Deploy and Host a Claude Code Dev Box on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/claude-code?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=claude-code)

This template gives you an always-on Ubuntu 24.04 workstation with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) pre-installed. Open your Railway domain for a terminal in the browser, or SSH in through Railway's TCP proxy. Your home directory lives on a volume, so repos, Claude login, GitHub auth and dotfiles survive every redeploy.

## About Hosting a Claude Code Dev Box

One service, one volume. The image ships `claude`, `git`, `gh`, Node 22, Python 3 + `uv`, `tmux`, `ripgrep`, `jq`, `vim`, build tools and an OpenSSH server. A `ttyd` web terminal (basic-auth gated) and `sshd` (password or key) both drop you into the same `tmux` session, so you can start a long Claude Code run from your laptop and pick it up from your phone. SSH host keys are stored on the volume, so your client never sees a "host key changed" warning after a redeploy.

## Common Use Cases

- Run Claude Code 24/7 on a task without keeping your laptop open
- Code from an iPad, Chromebook or phone: the browser terminal needs no SSH client
- A disposable root box with a stable IP for scripts, scraping, cron-style jobs or CI debugging
- Keep a persistent workspace for side projects that is reachable from anywhere

## Dependencies for Claude Code Dev Box Hosting

- None. Single service, no database.

### Deployment Dependencies

- [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code)
- [ttyd](https://github.com/tsl0922/ttyd) web terminal
- [GitHub CLI](https://cli.github.com/)

### Implementation Details

**First use:** open your Railway domain, log in with `WEB_USER` and the generated `WEB_PASSWORD` (service Variables tab). Run `claude` and complete `/login` by pasting the URL into a browser, or set `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token` on your own machine) or `ANTHROPIC_API_KEY` as a variable so it is signed in from the start.

**SSH:** Railway creates a TCP proxy for port 22 on deploy. Copy the host and port from Settings → Networking and run `ssh root@<host> -p <port>` with `ROOT_PASSWORD`, or add your public key to `AUTHORIZED_KEYS` and clear `ROOT_PASSWORD` for key-only login.

**Handy commands inside the box:**

- `cl` starts Claude Code inside a detachable `tmux` session named `claude`; `tmux attach -t claude` resumes it
- `gh auth login` or set `GH_TOKEN` to push to GitHub
- `claude update` upgrades Claude Code in place

Notes and limits:

- You are root. Anything you install outside `/root` disappears on redeploy; anything under `/root` stays.
- Give the service at least 1 GB of RAM. Claude Code plus a Node build comfortably uses more.
- There is no Docker daemon inside the box.
- The web terminal password is the whole security model for a root shell. Keep it strong and do not share the URL.

## Why Deploy a Claude Code Dev Box on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying a Claude Code dev box on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
