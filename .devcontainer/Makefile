.PHONY: list dc.up dc.status dc.stop dc.rebuild dc.rebuild.force dc.firewall.reload dc.down dc.down.volumes dc.shell dc.claude dc.claude.update dc.codex dc.codex.update dc.makefile.pull dc.bun.install dc.tidewave dc.tidewave.bg dc.tidewave.stop dc.tidewave.update dc.logs.proxy dc.server dc.server.stop dc.test dc.worktree.new dc.worktree.list dc.worktree.remove

# Absolute path of the directory holding this Makefile (i.e. .devcontainer),
# resolved independently of the caller's working directory.
HERE := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

define require_devcontainer
	@if [ "$$DEVCONTAINER" != "true" ]; then echo "Error: This command must be run inside the devcontainer." >&2; exit 1; fi
endef

# Remove a devcontainer volume by suffix, e.g. $(call remove_volume,-node-modules)
define remove_volume
	@vol=$$(basename $(CURDIR))$(1); \
	if docker volume inspect $$vol >/dev/null 2>&1; then \
		docker volume rm $$vol >/dev/null && echo "Volume removed: $$vol"; \
	else echo "No volume to remove: $$vol"; fi
endef

list:
	@printf "  %-22s  %s\n" \
		"make list"              "List all available commmands (you ran this)" \
		"" "" \
		"# Commands to run inside your project" "" \
		"make dc.up"             "Start the devcontainer" \
		"make dc.status"         "Show whether the devcontainer is running" \
		"make dc.stop"           "Stop the devcontainer (keeps container)" \
		"make dc.rebuild"        "Rebuild and start the devcontainer" \
		"make dc.firewall.reload" "Apply an edited allowed-domains.txt (no rebuild)" \
		"make dc.down"           "Stop and remove the devcontainer" \
		"make dc.down.volumes"   "Remove the node_modules, build, and deps volumes" \
		"make dc.shell"          "Open a shell inside the devcontainer" \
		"" "" \
		"# Commands to run inside the devcontainer" "" \
		"make dc.claude"         "Run Claude Code (with --dangerously-skip-permissions)" \
		"make dc.claude.update"  "Update Claude Code to the latest release" \
		"make dc.codex"          "Run Codex (with --dangerously-bypass-approvals-and-sandbox)" \
		"make dc.codex.update"   "Update Codex to the latest release" \
		"make dc.makefile.pull"  "Update this Makefile from the upstream devcontainer repo" \
		"make dc.bun.install"    "Installs the assets with bun" \
		"make dc.tidewave"       "Run Tidewave (exposed on localhost:9833)" \
		"make dc.tidewave.bg"    "Run Tidewave in the background" \
		"make dc.tidewave.stop"  "Stop background Tidewave" \
		"make dc.tidewave.update" "Update Tidewave CLI to the latest release" \
		"make dc.server"         "Starts the Phoenix server inside an IEx session" \
		"make dc.server.stop"    "Stops a Phoenix server left running (e.g. orphaned shell)" \
		"make dc.test"           "Runs the test suite using 'mix test'" \
		"make dc.logs.proxy"     "Print proxy logs" \
		"make dc.logs.tidewave"  "Print tidewave logs" \
		"" "" \
		"# Worktree commands (run inside the devcontainer)" "" \
		"make dc.worktree.new feature-x"      "Create worktree for branch feature-x (from HEAD)" \
		"make dc.worktree.new feature-x main" "Create worktree for branch feature-x (from main)" \
		"make dc.worktree.list"               "List all worktrees" \
		"make dc.worktree.remove x"           "Remove worktree x" \
		"wt feature-x"                        "Switch to git worktree feature-x" \
		"wt"                                  "Switch to main git worktree" \
		"" ""

dc.up:
	devcontainer up --workspace-folder .

dc.status:
	@id=$$(docker ps -qf "label=devcontainer.local_folder=$(CURDIR)"); \
	if [ -n "$$id" ]; then echo "Devcontainer is running ($$id)"; \
	else echo "Devcontainer is not running"; fi

dc.stop:
	@id=$$(docker ps -aqf "label=devcontainer.local_folder=$(CURDIR)"); \
	if [ -n "$$id" ]; then docker stop $$id; else echo "No devcontainer running"; fi

dc.rebuild:
	@$(MAKE) dc.down
	devcontainer up --workspace-folder .

dc.rebuild.force:
	@$(MAKE) dc.down
	devcontainer up --build-no-cache --workspace-folder .

# Apply an edited .devcontainer/allowed-domains.txt to the RUNNING container
# without a rebuild. The allowlist is baked into the image at build time
# (Dockerfile COPY → /etc/squid/allowed-domains.txt), so a plain restart won't
# pick up edits; this copies the new list in and reloads the proxy firewall
# (regenerates the SSL SNI regex, restarts Squid, reapplies the iptables rules)
# exactly as postStartCommand does — no rebuild, no app downtime.
dc.firewall.reload:
	@id=$$(docker ps -qf "label=devcontainer.local_folder=$(CURDIR)"); \
	if [ -z "$$id" ]; then echo "No devcontainer running (start it with 'make dc.up')."; exit 1; fi; \
	echo "Refreshing allowlist in $$id from $(HERE)/allowed-domains.txt ..."; \
	docker cp "$(HERE)/allowed-domains.txt" "$$id:/etc/squid/allowed-domains.txt"; \
	docker exec -u root "$$id" sh -c 'squid -k shutdown >/dev/null 2>&1 || true; \
		for i in 1 2 3 4 5; do pgrep -x squid >/dev/null 2>&1 || break; sleep 1; done; \
		/usr/local/bin/init-firewall.sh'; \
	echo "Firewall reloaded with the updated allowed-domains.txt (no rebuild)."

dc.down:
	@id=$$(docker ps -aqf "label=devcontainer.local_folder=$(CURDIR)"); \
	if [ -n "$$id" ]; then docker rm -f $$id >/dev/null && echo "Devcontainer removed: $$id"; else echo "No devcontainer to remove"; fi
	@$(MAKE) dc.down.volumes

dc.down.volumes:
	$(call remove_volume,-node-modules)
	$(call remove_volume,-build)
	$(call remove_volume,-deps)
	$(call remove_volume,-native)

dc.shell:
	exec devcontainer exec --workspace-folder . zsh

dc.claude:
	$(require_devcontainer)
	exec claude --dangerously-skip-permissions

dc.claude.update:
	$(require_devcontainer)
	@echo "Updating Claude Code to the latest release..."
	@npm install -g @anthropic-ai/claude-code@latest \
		&& echo "Claude Code updated: $$(claude --version 2>/dev/null || echo 'installed')"

dc.codex:
	$(require_devcontainer)
	exec codex --dangerously-bypass-approvals-and-sandbox

dc.codex.update:
	$(require_devcontainer)
	@echo "Updating Codex to the latest release..."
	@npm install -g @openai/codex@latest \
		&& echo "Codex updated: $$(codex --version 2>/dev/null || echo 'installed')"

dc.makefile.pull:
	@echo "Pulling latest Makefile from PJUllrich/devcontainer..."
	@curl -sL https://github.com/PJUllrich/devcontainer/archive/refs/heads/main.tar.gz \
		| tar xz --strip-components=2 devcontainer-main/.devcontainer/Makefile \
		&& echo "Makefile updated."

dc.bun.install:
	exec mix bun assets install

dc.tidewave:
	$(require_devcontainer)
	exec tidewave --allow-remote-access --allowed-origins http://localhost:9836

dc.tidewave.bg:
	@$(MAKE) dc.tidewave > /tmp/tidewave.log 2>&1 & echo "Tidewave started (pid $$!). Logs: /tmp/tidewave.log"

dc.tidewave.stop:
	$(require_devcontainer)
	@pkill -f tidewave && echo "Tidewave stopped" || echo "Tidewave is not running"

dc.tidewave.update:
	$(require_devcontainer)
	@ARCH=$$(uname -m); \
	case "$$ARCH" in \
		aarch64|arm64) ARCH=aarch64 ;; \
		x86_64|amd64)  ARCH=x86_64 ;; \
		*) echo "Unsupported architecture: $$ARCH" >&2; exit 1 ;; \
	esac; \
	echo "Downloading latest Tidewave CLI ($$ARCH)..."; \
	TIDEWAVE_BIN="$$HOME/.local/bin/tidewave"; \
	TIDEWAVE_TMP=$$(mktemp "$$HOME/.local/bin/.tidewave.XXXXXX"); \
	trap 'rm -f "$$TIDEWAVE_TMP"' EXIT; \
	curl -fsSL -o "$$TIDEWAVE_TMP" \
		https://github.com/tidewave-ai/tidewave_app/releases/latest/download/tidewave-cli-$$ARCH-unknown-linux-gnu \
	&& chmod +x "$$TIDEWAVE_TMP" \
	&& mv "$$TIDEWAVE_TMP" "$$TIDEWAVE_BIN" \
	&& trap - EXIT \
	&& echo "Tidewave updated: $$($$TIDEWAVE_BIN --version 2>/dev/null || echo 'installed')"

dc.logs.proxy:
	$(require_devcontainer)
	exec tail -f /var/log/squid/access.log

dc.logs.tidewave:
	$(require_devcontainer)
	exec tail -f /tmp/tidewave.log

dc.server:
	$(require_devcontainer)
	exec iex -S mix phx.server

dc.server.stop:
	$(require_devcontainer)
	@pkill -f "mix phx.server" && echo "Phoenix server stopped" || echo "Phoenix server is not running"

dc.test:
	$(require_devcontainer)
	MIX_ENV=test mix test

# --- Worktree commands ---
# Usage: make dc.worktree.new <name> [base-branch]
# The extra args are consumed via MAKECMDGOALS so make doesn't treat them as targets.
dc.worktree.new:
	$(require_devcontainer)
	$(eval WT_NAME := $(word 2,$(MAKECMDGOALS)))
	$(eval WT_BASE := $(word 3,$(MAKECMDGOALS)))
	@if [ -z "$(WT_NAME)" ]; then echo "Usage: make dc.worktree.new <name> [base-branch]"; exit 1; fi
	@if [ -n "$(WT_BASE)" ]; then \
		git worktree add .worktrees/$(WT_NAME) -b $(WT_NAME) $(WT_BASE); \
	else \
		git worktree add .worktrees/$(WT_NAME) -b $(WT_NAME); \
	fi

dc.worktree.list:
	$(require_devcontainer)
	@git worktree list

# Usage: make dc.worktree.remove <name>
dc.worktree.remove:
	$(require_devcontainer)
	$(eval WT_NAME := $(word 2,$(MAKECMDGOALS)))
	@if [ -z "$(WT_NAME)" ]; then echo "Usage: make dc.worktree.remove <name>"; exit 1; fi
	git worktree remove .worktrees/$(WT_NAME)

# Catch positional args passed after worktree targets so make doesn't error
%:
	@:
