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

# SHOPWARE_DEV_PROJECT_ID from the shell, else from .env next to compose.yml,
# where a project keeps it. Compose reads the rest of .env itself.
env_project_id=""
if [[ -f "$container_dir/.env" ]]; then
  env_project_id="$(sed -n 's/^SHOPWARE_DEV_PROJECT_ID=//p' "$container_dir/.env" | tail -n 1 | tr -d "\"'\r")"
fi

# Namespaces the containers, the images and the volumes per project.
project_id="${SHOPWARE_DEV_PROJECT_ID:-${env_project_id:-${project_basename}-${container_kind}}}"

# The Docker daemon is root-only unless the user is in the docker group.
docker_cmd=(docker)
docker info > /dev/null 2>&1 || docker_cmd=(sudo docker)

compose_cmd=("${docker_cmd[@]}" compose -p "$project_id" -f "$container_dir/compose.yml")

# Two projects with the same folder name get the same project_id, so they
# would share containers and volumes: a session would join the other
# project's container, and remove-docker.sh would delete its database. Compose
# labels every container with the directory of its compose.yml; stop when
# that is another directory that still exists. A directory that is gone is
# most likely this project before it moved.
this_dir="$(cd "$container_dir" && pwd -P)"
while IFS= read -r other_dir; do
  if [[ -n "$other_dir" && -d "$other_dir" && "$(cd "$other_dir" && pwd -P)" != "$this_dir" ]]; then
    echo "The name $project_id is taken by the project in $other_dir." >&2
    echo "Give this project its own name: set SHOPWARE_DEV_PROJECT_ID in $container_dir/.env" >&2
    echo "(see .env.example), for example SHOPWARE_DEV_PROJECT_ID=${project_id%-"$container_kind"}-2-$container_kind." >&2
    exit 1
  fi
done < <("${docker_cmd[@]}" ps --all --filter "label=com.docker.compose.project=$project_id" \
           --format '{{.Label "com.docker.compose.project.working_dir"}}' | sort -u)
