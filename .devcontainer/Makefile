.PHONY: list dc.up dc.rebuild dc.down dc.shell dc.claude dc.tidewave dc.tidewave.bg dc.tidewave.stop dc.logs.proxy dc.server dc.test dc.worktree.new dc.worktree.list dc.worktree.remove

list:
	@printf "  %-22s  %s\n" \
		"make list"              "List all available commmands (you ran this)" \
		"" "" \
		"# Commands to run inside your project" "" \
		"make dc.up"             "Start the devcontainer" \
		"make dc.rebuild"        "Rebuild and start the devcontainer" \
		"make dc.down"           "Stop and remove the devcontainer" \
		"make dc.shell"          "Open a shell inside the devcontainer" \
		"" "" \
		"# Commands to run inside the devcontainer" "" \
		"make dc.claude"         "Run Claude Code (with --dangerously-skip-permissions)" \
		"make dc.tidewave"       "Run Tidewave (exposed on localhost:9833)" \
		"make dc.tidewave.bg"    "Run Tidewave in the background" \
		"make dc.tidewave.stop"  "Stop background Tidewave" \
		"make dc.server"         "Starts the Phoenix server inside an IEx session" \
		"make dc.test"           "Runs the test suite using 'mix test'" \
		"make dc.logs.proxy"     "Print proxy logs (debug denied requests)" \
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

dc.rebuild:
	devcontainer up --workspace-folder . --remove-existing-container

dc.down:
	docker rm -f $$(docker ps -aqf "label=devcontainer.local_folder=$(CURDIR)")

dc.shell:
	devcontainer exec --workspace-folder . zsh

dc.claude:
	claude --dangerously-skip-permissions

dc.tidewave:
	tidewave --allow-remote-access --allowed-origins http://localhost:9833

dc.tidewave.bg:
	@$(MAKE) dc.tidewave > /tmp/tidewave.log 2>&1 & echo "Tidewave started (pid $$!). Logs: /tmp/tidewave.log"

dc.tidewave.stop:
	@pkill -f tidewave && echo "Tidewave stopped" || echo "Tidewave is not running"

dc.logs.proxy:
	tail -f /var/log/squid/access.log

dc.server:
	iex -S mix phx.server

dc.test:
	MIX_ENV=test mix test

# --- Worktree commands ---
# Usage: make dc.worktree.new <name> [base-branch]
# The extra args are consumed via MAKECMDGOALS so make doesn't treat them as targets.
dc.worktree.new:
	$(eval WT_NAME := $(word 2,$(MAKECMDGOALS)))
	$(eval WT_BASE := $(word 3,$(MAKECMDGOALS)))
	@if [ -z "$(WT_NAME)" ]; then echo "Usage: make dc.worktree.new <name> [base-branch]"; exit 1; fi
	@if [ -n "$(WT_BASE)" ]; then \
		git worktree add .worktrees/$(WT_NAME) -b $(WT_NAME) $(WT_BASE); \
	else \
		git worktree add .worktrees/$(WT_NAME) -b $(WT_NAME); \
	fi

dc.worktree.list:
	@git worktree list

# Usage: make dc.worktree.remove <name>
dc.worktree.remove:
	$(eval WT_NAME := $(word 2,$(MAKECMDGOALS)))
	@if [ -z "$(WT_NAME)" ]; then echo "Usage: make dc.worktree.remove <name>"; exit 1; fi
	git worktree remove .worktrees/$(WT_NAME)

# Catch positional args passed after worktree targets so make doesn't error
%:
	@:
