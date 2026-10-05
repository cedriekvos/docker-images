# Shared setup for the scripts in this directory. Source it, don't run it.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
container_dir="$(cd "$script_dir/.." && pwd)"
container_kind="$(basename "$container_dir")"
project_dir="$(cd "$container_dir/../.." && pwd)"
project_basename="$(basename "$project_dir" | tr '[:upper:] _' '[:lower:]--')"

# Namespaces the container, the image and the home volume per project.
project_id="${ANDROID_DEV_PROJECT_ID:-${project_basename}-${container_kind}}"

# The Docker daemon is root-only unless the user is in the docker group.
docker_cmd=(docker)
docker info > /dev/null 2>&1 || docker_cmd=(sudo docker)

compose_cmd=("${docker_cmd[@]}" compose -p "$project_id" -f "$container_dir/compose.yml")
