#!/usr/bin/env bash
set -euo pipefail

# Force the Docker Desktop socket to avoid "Docker Desktop is not running" errors.
# Allow override via DOCKER_MCP_HOST or DOCKER_HOST when needed.
DEFAULT_DOCKER_HOST="unix:///Users/petergiannopoulos/Library/Containers/com.docker.docker/Data/docker-cli.sock"
export DOCKER_HOST="${DOCKER_MCP_HOST:-${DOCKER_HOST:-$DEFAULT_DOCKER_HOST}}"

exec docker mcp gateway run
