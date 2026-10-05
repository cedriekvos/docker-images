#!/usr/bin/env bash
set -euo pipefail

# Tear down the android-development container's image, network, and home
# volume (login + history, Gradle caches, adb keys and debug keystore are
# erased).
#
# Run from anywhere:
#   docker/android-development/bin/remove-docker.sh

source "$(dirname "$0")/_common.sh"

# --volumes catches the home volume; --rmi local removes the built image too.
"${compose_cmd[@]}" down --volumes --rmi local --remove-orphans

echo "Removed resources for project_id=$project_id."
