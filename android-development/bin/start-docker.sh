#!/usr/bin/env bash
set -euo pipefail

# Run Claude Code, or the given command, in the android-development container.
# The first call starts the container, which is removed when that command
# exits (--rm). Calls made while it runs join it, so every terminal shares one
# adb server and one Gradle daemon. State persists via the home volume.
#
# Run from anywhere:
#   docker/android-development/bin/start-docker.sh [command...]

source "$(dirname "$0")/_common.sh"

if [[ -n "$("${docker_cmd[@]}" ps --quiet --filter "name=^${project_id}$")" ]]; then
  exec "${docker_cmd[@]}" exec -it "$project_id" "${@:-claude}"
fi

exec "${compose_cmd[@]}" run --rm --name "$project_id" android "$@"
