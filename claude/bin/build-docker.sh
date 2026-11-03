#!/usr/bin/env bash
set -euo pipefail

# Build the claude container image.
#
# Run from anywhere:
#   docker/claude/bin/build-docker.sh

source "$(dirname "$0")/_common.sh"

# SUDO_UID/SUDO_GID keep the real user when the script itself runs under sudo.
"${compose_cmd[@]}" build --no-cache \
  --build-arg UID="${SUDO_UID:-$(id -u)}" \
  --build-arg GID="${SUDO_GID:-$(id -g)}"
