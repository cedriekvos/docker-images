#!/usr/bin/env bash
set -euo pipefail

# Remove everything Docker holds for this project's java-development setup:
# the containers, the network, the home and database volumes and the built
# image, including images left behind by earlier builds. Login + history, the
# Maven and Gradle caches and the database's data are erased with the volumes.
#
# Run from anywhere:
#   docker/java-development/bin/remove-docker.sh

source "$(dirname "$0")/_common.sh"

# A session that is still running, or a container that was left behind.
if [[ -n "$("${docker_cmd[@]}" ps --all --quiet --filter "name=^${project_id}$")" ]]; then
  "${docker_cmd[@]}" rm --force "$project_id"
fi

# --volumes catches the home and database volumes; --rmi local removes the
# built image too.
"${compose_cmd[@]}" down --volumes --rmi local --remove-orphans

# Untagged images that earlier builds of this project left behind.
"${docker_cmd[@]}" image prune --force --filter "label=com.docker.compose.project=${project_id}"

echo "Removed resources for project_id=$project_id."
