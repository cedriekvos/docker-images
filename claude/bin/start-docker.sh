#!/usr/bin/env bash
set -euo pipefail

# Run a one-shot, interactive Claude Code session in a container.
# The container is removed on exit (--rm). State persists via the
# claude-home volume (namespaced by CLAUDE_PROJECT_ID).
#
# Run from anywhere:
#   docker/claude/bin/start-docker.sh

source "$(dirname "$0")/_common.sh"

# Color support of the terminal this runs in. Docker sets TERM=xterm and no
# COLORTERM, which makes Claude Code draw with 16 colors: its gray text turns
# white, unreadable on a light background. Passed here rather than in
# compose.yml: sudo drops COLORTERM from the environment.
term_args=(--env TERM=xterm-256color)
if [[ -n "${COLORTERM:-}" ]]; then
  term_args+=(--env "COLORTERM=$COLORTERM")
fi

exec "${compose_cmd[@]}" run --rm "${term_args[@]}" claude
