#!/usr/bin/env bash
set -euo pipefail

# Run Claude Code, or the given command, in the java-development container.
# The first call starts the container, which is removed when that command
# exits (--rm). Calls made while it runs join it, so every terminal shares one
# Gradle daemon. State persists via the home volume.
#
# Run from anywhere:
#   docker/java-development/bin/start-docker.sh [command...]

source "$(dirname "$0")/_common.sh"

# Color support of the terminal this runs in. Docker sets TERM=xterm and no
# COLORTERM, which makes Claude Code draw with 16 colors: its gray text turns
# white, unreadable on a light background. Passed here rather than in
# compose.yml: sudo drops COLORTERM from the environment.
term_args=(--env TERM=xterm-256color)
if [[ -n "${COLORTERM:-}" ]]; then
  term_args+=(--env "COLORTERM=$COLORTERM")
fi

if [[ -n "$("${docker_cmd[@]}" ps --quiet --filter "name=^${project_id}$")" ]]; then
  exec "${docker_cmd[@]}" exec -it "${term_args[@]}" "$project_id" "${@:-claude}"
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

# --service-ports publishes the ports listed in compose.yml, if there are any.
exec "${compose_cmd[@]}" run --rm --service-ports --name "$project_id" "${term_args[@]}" "${run_args[@]}" java "$@"
