#!/usr/bin/env bash
set -euo pipefail

# Build the java-development container image.
# Extra arguments go to `docker compose build` (--no-cache,
# --build-arg JDK_VERSION=21, ...).
#
# Run from anywhere:
#   docker/java-development/bin/build-docker.sh

source "$(dirname "$0")/_common.sh"

# SUDO_UID/SUDO_GID keep the real user when the script itself runs under sudo.
"${compose_cmd[@]}" build \
  --build-arg UID="${SUDO_UID:-$(id -u)}" \
  --build-arg GID="${SUDO_GID:-$(id -g)}" \
  "$@"
