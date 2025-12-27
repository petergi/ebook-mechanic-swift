# Docker MCP Gateway Runbook

## Overview
The Docker MCP gateway is a long-running process that starts a set of MCP servers via Docker. Because I don't retain state across sessions, the most reliable way to reproduce the setup is to capture the exact startup steps and environment assumptions in a dedicated project document.

In our case, the key requirement was that Docker Desktop be fully running and that the MCP gateway can access the correct Docker Desktop socket. Once that was satisfied, the command started the gateway and brought up the configured MCP servers.

## Why this matters for future sessions
- I can't remember prior actions across sessions, so a file-based runbook is the best way to preserve the procedure.
- A consistent startup doc prevents confusion when the gateway says Docker Desktop is not running even though `docker info` works.
- Having a single source of truth makes it easy for you (or any future agent) to bring the gateway up quickly.

## Baseline checks
Before starting the gateway:
- Verify Docker Desktop is running and reports an active engine.
- Confirm the Docker socket path available to the CLI.

Suggested checks:
- `docker info`
- `docker context ls`
- `ls -l /Users/petergiannopoulos/Library/Containers/com.docker.docker/Data/docker-cli.sock`

## Primary command
Run the gateway with the socket explicitly set (this was the key fix):

```
DOCKER_HOST=unix:///Users/petergiannopoulos/Library/Containers/com.docker.docker/Data/docker-cli.sock docker mcp gateway run
```

If the gateway reports Docker Desktop is not running, confirm the socket path and try the fallback options below.

## Options for repeatable startup

### Option A: Project script (recommended)
Create a script that always uses the known socket path and can be run per session.

Example: `Scripts/run-mcp-gateway.sh`
```
#!/usr/bin/env bash
set -euo pipefail
DEFAULT_DOCKER_HOST="unix:///Users/petergiannopoulos/Library/Containers/com.docker.docker/Data/docker-cli.sock"
export DOCKER_HOST="${DOCKER_MCP_HOST:-${DOCKER_HOST:-$DEFAULT_DOCKER_HOST}}"
exec docker mcp gateway run
```

Override examples:
```
DOCKER_MCP_HOST=unix:///custom.sock Scripts/run-mcp-gateway.sh
```
```
DOCKER_HOST=unix:///custom.sock Scripts/run-mcp-gateway.sh
```

### Option B: Shell alias
Add a shortcut in your shell profile:
```
alias mcp-gateway='DOCKER_HOST=unix:///Users/petergiannopoulos/Library/Containers/com.docker.docker/Data/docker-cli.sock docker mcp gateway run'
```

### Option C: Per-project README/AGENTS note
Add a short note in project docs so the command is discoverable by anyone:

```
MCP Gateway:
DOCKER_HOST=unix:///Users/petergiannopoulos/Library/Containers/com.docker.docker/Data/docker-cli.sock docker mcp gateway run
```

## Fallbacks if the gateway still fails
- Ensure Docker Desktop shows "Engine running" in the UI.
- Run `docker context ls` and confirm the active context is `desktop-linux`.
- Try the alternate socket shown by Docker Desktop:
  - `DOCKER_HOST=unix:///Users/petergiannopoulos/.docker/run/docker.sock docker mcp gateway run`
- If `docker desktop status` fails with permissions, rerun with elevated permissions or ensure terminal has access to Docker Desktop logs.

## Notes from this session
- We had repeated `Docker Desktop is not running` errors until we attempted direct socket overrides.
- Once run with escalated permissions, the gateway started and the MCP servers initialized, with `openapi-schema` failing but the rest succeeding.
