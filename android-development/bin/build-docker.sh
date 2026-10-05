#!/usr/bin/env bash
set -euo pipefail

# Build the android-development container image.
# Extra arguments go to `docker compose build` (--no-cache,
# --build-arg ANDROID_PLATFORM=35, ...).
#
# Run from anywhere:
#   docker/android-development/bin/build-docker.sh

source "$(dirname "$0")/_common.sh"

# SUDO_UID/SUDO_GID keep the real user when the script itself runs under sudo.
"${compose_cmd[@]}" build \
  --build-arg UID="${SUDO_UID:-$(id -u)}" \
  --build-arg GID="${SUDO_GID:-$(id -g)}" \
  "$@"
