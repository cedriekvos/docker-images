# Shared setup for the scripts in this directory. Source it, don't run it.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
container_dir="$(cd "$script_dir/.." && pwd)"
container_kind="$(basename "$container_dir")"
project_dir="$(cd "$container_dir/../.." && pwd)"

# A compose project name may only hold lowercase letters, digits, dashes and
# underscores, and starts with a letter or digit. Each space and underscore
# becomes a dash, as it always has; a run of any other characters, such as the
# dot in example.com, becomes one dash too.
project_basename="$(basename "$project_dir" | LC_ALL=C tr '[:upper:] _' '[:lower:]--' | LC_ALL=C sed 's/[^a-z0-9-]\{1,\}/-/g; s/^-*//')"

# Namespaces the compose project, the network and the home volume per project.
project_id="${CLAUDE_PROJECT_ID:-${project_basename}-${container_kind}}"

# The Docker daemon is root-only unless the user is in the docker group.
docker_cmd=(docker)
docker info > /dev/null 2>&1 || docker_cmd=(sudo docker)

compose_cmd=("${docker_cmd[@]}" compose -p "$project_id" -f "$container_dir/compose.yml")
