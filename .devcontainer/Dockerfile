ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.3.2
ARG DEBIAN_VERSION=trixie-20260202-slim

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
    locales \
    gcc \
    make \
    libc-dev \
    inotify-tools \
    nodejs \
    npm \
    squid-openssl \
    && ln -sf /usr/bin/vim.tiny /usr/bin/vim \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && update-ca-certificates \
    && rm -rf /usr/share/doc /usr/share/man /usr/share/info \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

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
RUN mkdir -p /workspace /home/$USERNAME/.claude /home/$USERNAME/.mix /home/$USERNAME/.hex \
    && chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.claude /home/$USERNAME/.mix /home/$USERNAME/.hex

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
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(curl -fsSL https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git \
    -p fzf \
    -p mix \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    -x \
    && echo 'autoload -Uz compinit && compinit -i' >> /home/dev/.zshrc \
    && echo "zstyle ':completion:*:make:*' tag-order targets" >> /home/dev/.zshrc \
    && echo 'wt() { cd /workspace/.worktrees/$1 2>/dev/null || cd /workspace; }' >> /home/dev/.zshrc

# Install Claude Code via npm (faster and cacheable)
ENV PATH=$PATH:/home/$USERNAME/.local/bin
ENV NPM_CONFIG_PREFIX=/home/$USERNAME/.local
RUN npm install -g @anthropic-ai/claude-code && npm cache clean --force

# Install Tidewave CLI (optional, disable with INSTALL_TIDEWAVE=false)
ARG INSTALL_TIDEWAVE
ARG TARGETARCH
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
    echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh, /usr/local/bin/init-file-protection.sh, /usr/bin/bash /workspace/.devcontainer/setup/init-file-protection.sh" > /etc/sudoers.d/$USERNAME-firewall && \
    chmod 0440 /etc/sudoers.d/$USERNAME-firewall
USER $USERNAME
