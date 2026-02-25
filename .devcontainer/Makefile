.PHONY: list dc.up dc.rebuild dc.down dc.shell dc.claude dc.tidewave dc.tidewave.bg dc.logs.proxy dc.server dc.test

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
		"make dc.server"         "Starts the Phoenix server inside an IEx session" \
		"make dc.test"           "Runs the test suite using 'mix test'" \
		"make dc.logs.proxy" "Print proxy logs (debug denied requests)" \
		"" ""

dc.up:
	devcontainer up --workspace-folder .

dc.rebuild:
	$(MAKE) dc.down
	$(MAKE) dc.up

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

dc.logs.proxy:
	tail -f /var/log/squid/access.log

dc.server:
	iex -S mix phx.server

dc.test:
	MIX_ENV=test mix test
