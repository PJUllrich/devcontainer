# An Elixir Devcontainer for Phoenix, Claude Code, and Tidewave

A devcontainer for Elixir and Phoenix development with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and optionally [Tidewave](https://tidewave.dev/).

The container makes it safe(-er) to run Claude with `--dangerously-skip-permissions` by:
* Restricting all outbound traffic to a domain allowlist via a 
strict network firewall
* Hiding sensitive files (e.g. `.env`) from Claude using file permissions, with Claude deny rules as a secondary safeguard
* Isolating Claude state in a per-project `.claude` folder, separate from your host's `~/.claude`

## Download

Run this from your project root to download only the `.devcontainer/` directory:

```bash
curl -sL https://github.com/PJUllrich/devcontainer/archive/refs/heads/main.tar.gz \
  | tar xz --strip-components=1 devcontainer-main/.devcontainer
```

## Quick start

> Requires the [devcontainer CLI](https://github.com/devcontainers/cli) (`npm install -g @devcontainers/cli`).

1. Copy the `.devcontainer/` directory into your Elixir project root.
2. Create a root `Makefile` that includes the devcontainer Makefile with: 
```bash
echo 'include .devcontainer/Makefile' > Makefile
```
3. Add project-specific environment variables in `devcontainer.json`
4. Customize the protected filepaths in `protected-paths.txt`
5. Customize the allowed domains in `allowed-domains.txt`
6. Run `make dc.up` to start the container, then `make dc.shell` to open a shell inside it.
7. Run `make dc.claude` to start Claude in unsafe mode.
8. To access Tidewave, run `make dc.tidewave.bg` to start Tidewave in the background (exposed on [localhost:9833](http://localhost:9833)) and then start your app with `make dc.server` or `mix phx.server`.

## Makefile commands

Run `make list` to see all available commands.

## Git

Git is available inside the container with `safe.directory` pre-configured for `/workspace` and all worktree paths. Credentials are forwarded automatically by the devcontainer CLI when your host has a Git credential helper configured (e.g. `gh auth`). The zsh prompt shows git branch and status by default.

## Git Worktrees

Worktrees let you work on multiple branches simultaneously with isolated file changes but shared mix/hex caches. They live under `.worktrees/` in the project root and sync to your host via the bind mount.

### Managing worktrees

```bash
# Create a worktree (new branch from HEAD)
make dc.worktree.new feature-x

# Create a worktree branching from main
make dc.worktree.new feature-x main

# List all worktrees
make dc.worktree.list

# Switch to a worktree
wt feature-x

# Return to the main workspace
wt

# Remove a worktree
make dc.worktree.remove feature-x
```

### Running multiple Claude instances in parallel

Open multiple shells and run Claude in different worktrees — each instance works on its own branch with isolated file changes:

```bash
# Terminal 1
make dc.shell
wt feature-auth
make dc.claude

# Terminal 2
make dc.shell
wt feature-billing
make dc.claude
```

## Adding allowed domains

Edit `.devcontainer/allowed-domains.txt` to add or remove domains:

```txt
# A leading dot matches the domain and all subdomains
.example.com          # matches example.com, api.example.com, etc.

# Without a leading dot, only the exact domain is matched
cdn.example.com       # matches cdn.example.com only
```

After changing the file, rebuild the container with `make dc.rebuild`.

## Adding environment variables

Environment variables are configured in `.devcontainer/devcontainer.json` in two sections:

### `remoteEnv` 

For secrets and values that should refresh from your host on each container restart:

```jsonc
"remoteEnv": {
  "MY_API_KEY": "${localEnv:MY_API_KEY}",
  "DATABASE_HOST": "host.docker.internal",
},
```

The `${localEnv:VAR_NAME}` syntax pulls the value from your host machine's environment. Set these variables in your shell profile (e.g., `~/.zshrc`) or use `direnv` or `dotenv`.

### `containerEnv`
For configuration that is baked in at container creation time and does not change between restarts:

```jsonc
"containerEnv": {
  "CLAUDE_CONFIG_DIR": "/home/dev/.claude",
},
```

## Adding Protected paths

Files listed in `.devcontainer/protected-paths.txt` are hidden from the container at startup using bind mounts. The container sees an empty file (or directory) in place of the original — the host files are unaffected.

```txt
# Exact filename in the project root
.env
.env.*

# Path relative to the project root
config/secrets.yml

# Recursive match (any depth)
**/.env
```

By default, `.env` and `.env.*` are protected. Edit the file to add project-specific paths, then rebuild with `make dc.rebuild`.

### Project-level deny rules

On container start, `init-file-protection.sh` also creates a Claude project-level `settings.json` with deny rules generated from `protected-paths.txt` as a secondary safeguard. For example, the default `protected-paths.txt` produces:

```json
{
  "permissions": {
    "deny": [
      "Read(path:**/.env)",
      "Read(path:**/.env.*)"
    ]
  }
}
```

This file is written into the project's `.claude/` directory on container start.

## Connecting to Postgres

The container connects to your host's Postgres instance assumed to run in Docker via `host.docker.internal`. To make this work, configure the hostname in `config/dev.exs` and `config/test.exs`:

```elixir
# config/dev.exs **and** config/test.exs
config :my_app, MyApp.Repo,
  # other configs
  hostname: System.get_env("DATABASE_HOST", "localhost")
```

The `devcontainer.json` sets `DATABASE_HOST` to `host.docker.internal` via `remoteEnv`, so the repo will connect to your host's Postgres when running inside the container and to `localhost` when running outside it.

## Disabling Tidewave

To disable Tidewave, make two changes:

1. In `.devcontainer/Dockerfile`, set the build arg to `false`:

   ```dockerfile
   ARG INSTALL_TIDEWAVE=false
   ```

2. In `.devcontainer/devcontainer.json`, remove the Tidewave port mapping from `runArgs`:

   ```jsonc
   // Before
   "runArgs": ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW", "-p", "4000:4000", "-p", "9833:9832"],

   // After
   "runArgs": ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW", "-p", "4000:4000"],
   ```

Then rebuild with `make dc.rebuild`.

## How the firewall works

The container uses a layered approach to make `--dangerously-skip-permissions` safer:

### Network isolation

All outbound HTTP/HTTPS traffic is transparently intercepted by [Squid](https://www.squid-cache.org/) and filtered against the domain allowlist in `allowed-domains.txt`. Unlike a traditional forward proxy that relies on processes respecting `HTTP_PROXY` environment variables, this uses iptables `REDIRECT` rules to catch **all** traffic regardless of the client. HTTP is filtered by `Host` header, HTTPS by reading the SNI hostname from the TLS ClientHello via peek-and-splice — no TLS decryption happens. All other outbound traffic (except DNS, localhost, and the Docker host network) is dropped by default.

On container start, `init-firewall.sh` verifies the rules by confirming that blocked domains are unreachable and allowed domains are reachable. If any check fails, the container will not start.

### Known limitations

The firewall reduces the attack surface significantly but is not a complete sandbox:

- **No general sudo:** The `dev` user only has scoped sudo access for the firewall init script. Claude cannot escalate privileges to flush iptables rules or modify system configuration. If you need general sudo for ad-hoc tasks, you can add it back in the Dockerfile, but this weakens the firewall guarantee.
- **Runtime environment variables:** The `.env` deny rules prevent reading `.env` *files*, but secrets injected via `remoteEnv` are still visible through `printenv` or `/proc/self/environ`. Avoid putting highly sensitive secrets in `remoteEnv` if this is a concern.
- **Non-HTTP protocols:** The firewall only restricts ports 80 and 443. Traffic on other ports (other than DNS and localhost) is blocked by the default DROP policy, but if you add custom allow rules, those channels are unfiltered.

## Design decisions

**npm install over the native Claude installer:** Claude Code is installed via `npm install -g @anthropic-ai/claude-code` rather than the native install script. The npm install is faster and produces a cacheable Docker layer.

## Customizing the base image

The Dockerfile uses `hexpm/elixir` as the base image. To change the Elixir or OTP version, edit the build args at the top of `.devcontainer/Dockerfile`:

```dockerfile
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.3.2
ARG DEBIAN_VERSION=trixie-20260202-slim
```