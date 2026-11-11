#!/usr/bin/env bash
set -euo pipefail

# Run a one-shot, interactive Claude Code session in a container.
# The container is removed on exit (--rm). State persists via the
# home volume (namespaced by CLAUDE_PROJECT_ID). Arguments go to Claude Code.
#
# Run from anywhere:
#   docker/claude/bin/start-docker.sh [claude arguments...]

source "$(dirname "$0")/_common.sh"

# Color support of the terminal this runs in. Docker sets TERM=xterm and no
# COLORTERM, which makes Claude Code draw with 16 colors: its gray text turns
# white, unreadable on a light background. Passed here rather than in
# compose.yml: sudo drops COLORTERM from the environment.
term_args=(--env TERM=xterm-256color)
if [[ -n "${COLORTERM:-}" ]]; then
  term_args+=(--env "COLORTERM=$COLORTERM")
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

# This machine's time zone, so that dates and times in the container are the
# ones you see here: TZ when it is set, else the zone /etc/localtime points
# to. Without it the container runs in UTC. Passed here rather than in
# compose.yml: sudo drops TZ from the environment.
host_tz="${TZ:-$(readlink /etc/localtime 2> /dev/null | sed -n 's|^.*/zoneinfo/||p' || true)}"
if [[ -n "$host_tz" ]]; then
  run_args+=(--env "TZ=$host_tz")
fi

exec "${compose_cmd[@]}" run --rm "${term_args[@]}" "${run_args[@]}" claude "$@"
