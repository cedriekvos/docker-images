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

# Git identity and settings from the host, read-only, as the container's
# system-wide config. Mounted here rather than in compose.yml: sudo would
# resolve a ~ in that file to root's home.
host_home="$(getent passwd "${SUDO_UID:-$(id -u)}" | cut -d: -f6)"
git_config="$host_home/.config/git/config"
run_args=()
if [[ -f "$git_config" ]]; then
  run_args+=(--volume "$git_config:/etc/gitconfig:ro")
fi

exec "${compose_cmd[@]}" run --rm --name "$project_id" "${run_args[@]}" android "$@"
