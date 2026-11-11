#!/usr/bin/env bash
set -euo pipefail

# Tear down the claude container's image, network, and named volume
# (the home volume — Claude Code, login + history are erased).
#
# Run from anywhere:
#   docker/claude/bin/remove-docker.sh

source "$(dirname "$0")/_common.sh"

# --volumes catches the home volume; --rmi local removes the built image too.
"${compose_cmd[@]}" down --volumes --rmi local --remove-orphans

echo "Removed resources for project_id=$project_id."
