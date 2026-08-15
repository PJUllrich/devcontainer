ARG ELIXIR_VERSION=1.20.3
ARG OTP_VERSION=29.0.5
ARG DEBIAN_VERSION=trixie-20260803-slim

ARG NODE_VERSION=24.18.1

ARG INSTALL_RUST=false
ARG RUST_VERSION=1.97.0

ARG INSTALL_BUN=false
ARG BUN_VERSION=1.2.19

ARG INSTALL_CODEX=false
ARG INSTALL_CLAUDE_CODE=false

# Installs the Tidewave CLI by default. Set to `false` and remove the port mapping
# from `devcontainer.json` if you don't want to install Tidewave.
ARG INSTALL_TIDEWAVE=true

ARG IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"

FROM ${IMAGE} AS devcontainer

ARG TZ
ENV TZ="$TZ"

# Install basic development tools, iptables/ipset, and build dependencies
# Note: uses gcc/make/libc-dev instead of build-essential to save ~50-80MB.
# If NIF compilation fails, switch back to build-essential.
RUN apt-get update && apt-get install -y --no-install-recommends \
    less \
    git \
    procps \
    sudo \
    fzf \
    zsh \
    unzip \
    curl \
    ca-certificates \
    iptables \
    ipset \
    iproute2 \
    jq \
    vim-tiny \
    gcc \
    make \
    libc-dev \
    inotify-tools \
    xz-utils \
    squid-openssl \
    openssh-client \
    && ln -sf /usr/bin/vim.tiny /usr/bin/vim \
    && update-ca-certificates \
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install the pinned Node.js release and its bundled npm from the official binaries.
ARG NODE_VERSION
ARG TARGETARCH
RUN case "$TARGETARCH" in \
    amd64) NODE_ARCH=x64 ;; \
    arm64) NODE_ARCH=arm64 ;; \
    *) echo "Unsupported Node.js architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && NODE_DIST="node-v${NODE_VERSION}-linux-${NODE_ARCH}" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
    && grep " ${NODE_DIST}.tar.xz$" SHASUMS256.txt | sha256sum --check --strict - \
    && tar -xJf "${NODE_DIST}.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && rm "${NODE_DIST}.tar.xz" SHASUMS256.txt \
    && rm -rf /usr/local/include/node /usr/local/share/doc/node \
    && rm -f /usr/local/share/man/man1/node.1 \
    /usr/local/CHANGELOG.md /usr/local/LICENSE /usr/local/README.md

ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create non-root dev user (no general sudo — only scoped sudo for the firewall init script)
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Persist shell history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory

# Set DEVCONTAINER environment variable
ENV DEVCONTAINER=true

# Create workspace and config directories
RUN mkdir -p /workspace /home/$USERNAME/.local/bin /home/$USERNAME/.claude \
    /home/$USERNAME/.mix /home/$USERNAME/.hex \
    && chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.local \
    /home/$USERNAME/.claude /home/$USERNAME/.mix /home/$USERNAME/.hex

WORKDIR /workspace

# Initialize Squid directories, certs, and SSL database (stable, rarely changes)
RUN mkdir -p /var/log/squid /var/spool/squid && chown -R proxy:proxy /var/log/squid /var/spool/squid && chmod 755 /var/log/squid \
    && openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/CN=squid-bump" \
    -keyout /etc/squid/bump.key -out /etc/squid/bump.crt \
    && chown proxy:proxy /etc/squid/bump.* && chmod 600 /etc/squid/bump.* \
    && /usr/lib/squid/security_file_certgen -c -s /var/spool/squid/ssl_db -M 4MB \
    && chown -R proxy:proxy /var/spool/squid/ssl_db

# Switch to non-root user
USER $USERNAME

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Allow git operations in /workspace and all worktree paths
RUN git config --global --add safe.directory '*'

# Set the default shell to zsh
ENV SHELL=/bin/zsh

# Set the default editor (vim.tiny is symlinked to vim)
ENV EDITOR=vim
ENV VISUAL=vim

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.1
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -p mix \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    -x \
    && echo 'autoload -Uz compinit && compinit -i' >> /home/dev/.zshrc \
    && echo "zstyle ':completion:*:make:*' tag-order targets" >> /home/dev/.zshrc \
    && echo 'wt() { cd /workspace/.worktrees/$1 2>/dev/null || cd /workspace; }' >> /home/dev/.zshrc \
    && rm -rf /home/$USERNAME/.oh-my-zsh/.git \
    /home/$USERNAME/.oh-my-zsh/custom/themes/powerlevel10k/.git \
    /home/$USERNAME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/.git

# Install AI coding CLIs via npm (optional, disable with the corresponding build arg)
ARG INSTALL_CODEX
ARG INSTALL_CLAUDE_CODE
ENV PATH=$PATH:/home/$USERNAME/.local/bin
ENV NPM_CONFIG_PREFIX=/home/$USERNAME/.local
RUN if [ "$INSTALL_CLAUDE_CODE" = "true" ]; then \
    npm install -g @anthropic-ai/claude-code; \
    fi \
    && if [ "$INSTALL_CODEX" = "true" ]; then \
    npm install -g @openai/codex; \
    fi \
    && if [ "$INSTALL_CLAUDE_CODE" = "true" ] || [ "$INSTALL_CODEX" = "true" ]; then \
    npm cache clean --force; \
    fi

# Install Rust (cargo) without rust-docs; the minimal profile only includes
# rustc, rust-std, and cargo.
ARG INSTALL_RUST
ARG RUST_VERSION
ENV RUSTUP_HOME=/home/$USERNAME/.rustup
ENV CARGO_HOME=/home/$USERNAME/.cargo
ENV PATH=$PATH:/home/$USERNAME/.cargo/bin
RUN if [ "$INSTALL_RUST" = "true" ]; then \
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --profile minimal --default-toolchain "$RUST_VERSION" \
    && cargo install cargo-audit --locked \
    && rm -rf "$CARGO_HOME/registry" "$CARGO_HOME/git"; \
    fi

# Install Bun — version pinned to match .tool-versions
ARG INSTALL_BUN
ARG BUN_VERSION
ENV BUN_INSTALL=/home/$USERNAME/.bun
ENV PATH=$PATH:/home/$USERNAME/.bun/bin
RUN if [ "$INSTALL_BUN" = "true" ]; then \
    curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}"; \
    fi

# Install Tidewave CLI (optional, disable with INSTALL_TIDEWAVE=false)
ARG INSTALL_TIDEWAVE
RUN if [ "$INSTALL_TIDEWAVE" = "true" ]; then \
    ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") \
    && curl -fsSL -o /home/$USERNAME/.local/bin/tidewave \
    https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-${ARCH}-unknown-linux-gnu \
    && chmod +x /home/$USERNAME/.local/bin/tidewave; \
    fi

# Copy config files and scripts (late to maximize cache hits)
COPY setup/squid.conf /etc/squid/squid.conf
COPY allowed-domains.txt /etc/squid/allowed-domains.txt
COPY protected-paths.txt /etc/devcontainer/protected-paths.txt
COPY setup/init-firewall.sh setup/init-file-protection.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/init-file-protection.sh && \
    echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh, /usr/local/bin/init-file-protection.sh, /usr/bin/bash /workspace/.devcontainer/setup/init-file-protection.sh, /usr/bin/bash /workspace/.devcontainer/setup/init-git-https.sh" > /etc/sudoers.d/$USERNAME-firewall && \
    chmod 0440 /etc/sudoers.d/$USERNAME-firewall
USER $USERNAME
