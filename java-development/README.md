# `java-development` container

A self-contained, per-project Docker setup for Java development with Claude Code. The image carries the JDK, Maven, Gradle and Claude Code, so building and testing happen inside the container. A PostgreSQL database runs next to it. The host only needs Docker.

## Layout

```
docker/java-development/
├── Dockerfile       # Ubuntu + JDK + Maven + Gradle + Claude Code, non-root user matching host UID/GID
├── compose.yml      # the `java` service (one-shot, --rm on exit) and a PostgreSQL database
├── README.md
└── bin/
    ├── build-docker.sh     # build the image
    ├── start-docker.sh     # run Claude Code, or any other command, in the container
    ├── remove-docker.sh    # remove the project's containers, network, volumes and images
    └── _common.sh          # shared by the three scripts
```

## Usage

```sh
# Build once (or after editing the Dockerfile)
docker/java-development/bin/build-docker.sh

# Launch an interactive Claude session in the project root
docker/java-development/bin/start-docker.sh

# While that session runs: a shell or a one-off command in the same container
docker/java-development/bin/start-docker.sh bash
docker/java-development/bin/start-docker.sh mvn verify

# Tear everything down (deletes login, history, the Maven and Gradle caches and the database!)
docker/java-development/bin/remove-docker.sh
```

Run the scripts as yourself. They call `sudo docker` on their own when your user is not allowed to talk to the Docker daemon.

## What is in the image

Versions are build arguments. Change the defaults in the `Dockerfile`, or pass `--build-arg NAME=value` to `build-docker.sh`.

| Build arg | Default | Sets |
|---|---|---|
| `JDK_VERSION` | `25` | JDK that builds and runs the project |
| `MAVEN_VERSION` | `3.10.0` | Maven (`mvn`) |
| `GRADLE_VERSION` | `9.8.0` | Gradle (`gradle`) |

When a project has its own `./mvnw` or `./gradlew`, build with that: the wrapper pins the build tool version for the project. The copies in the image are for projects without a wrapper and for creating one.

Git comes from the Ubuntu Git maintainers' archive rather than from Ubuntu itself.

## Claude Code updates

Claude Code is installed in the home directory, so the copy that runs lives in the `home` volume and updates itself there. An update that was downloaded during a session takes effect at the next start.

Docker fills the volume from the image only once, when the volume is new. Rebuilding the image afterwards does not change Claude Code in an existing project. If an update ever goes wrong, open a shell with `start-docker.sh bash` and run `claude update`, or reinstall with `curl -fsSL https://claude.ai/install.sh | bash`.

## Starting a new project

`gradle init` creates a project, wrapper included. For Maven, `mvn archetype:generate` creates the project and `mvn wrapper:wrapper` adds the wrapper. You can also ask Claude to scaffold it.

## Reaching a server from the host

Port 8080 is published: a web application listening on it in the container is reachable at `http://localhost:8080` on the host. The `127.0.0.1` in front keeps it reachable from this machine only, not from the rest of the network.

Other ports are added the same way under the `java` service in `compose.yml`:

```yaml
    ports:
      - "127.0.0.1:8080:8080"
      - "127.0.0.1:9090:9090"
```

`start-docker.sh` publishes the listed ports when it starts the container. Two projects cannot publish the same host port at the same time: the second one fails to start. Change the middle number in one of them, for example `127.0.0.1:8081:8080`.

## Database

A PostgreSQL 18 server starts together with the first session. The database, the user and the password are all called `dev`.

| From | Host | Port |
|---|---|---|
| The application, inside the `java` container | `db` | `5432` |
| A database GUI on this machine (TablePlus, DataGrip, DBeaver, …) | `localhost` | `5432` |

For Spring Boot:

```properties
spring.datasource.url=jdbc:postgresql://db:5432/dev
spring.datasource.username=dev
spring.datasource.password=dev
```

The database keeps running after the session ends, so a GUI can stay connected, and the next `start-docker.sh` reuses it. Stop it with `docker stop` or a tool such as lazydocker when you don't need it. Its data lives in the `db` volume: it survives sessions, stops and rebuilds, and is erased by `remove-docker.sh`.

Port 5432 is published on this machine only, like port 8080. Only one project can hold it at a time, and a database that is still running from another project counts: stop that one first, or give this project another host port in `compose.yml`, for example `127.0.0.1:5433:5432`.

A project without a database can delete the `db` service, the `depends_on` block and the `db` volume from `compose.yml`.

## How it isolates per project

The scripts derive a unique compose project name from the dir above `docker/`:

```
/home/you/billing-api/docker/java-development/  →  billing-api-java-development
```

That name covers the containers, the image, the network and the volumes, so two projects don't share login state, caches or data. If two projects share a basename, set `JAVA_DEV_PROJECT_ID` before running the scripts.

## What gets mounted

| Host | Container | Why |
|---|---|---|
| `../..` (the project root containing `docker/`) | `/workspace` | Your code, live |
| `home` (named volume) | `/home/dev` | Claude Code with its login + history, Maven repository (`~/.m2`), Gradle caches (`~/.gradle`) |
| `~/.config/git/config` | `/etc/gitconfig` (read-only) | Your git name, email and settings; added by `start-docker.sh` when the file exists |
| `db` (named volume) | `/var/lib/postgresql` in the `db` container | The database's data |

## Not included

- **An IDE.** No visual debugger or profiler. Everything goes through Maven, Gradle and Claude.
- **Docker inside the container.** Tests that start containers themselves, such as Testcontainers, cannot run here. Point them at the `db` service instead.
- **Other services.** PostgreSQL is the only one set up; there is no message broker, cache or mail server.
- **Git credentials.** Commits made in the container carry your name and email, but there are no SSH keys or tokens inside. Push from the host.

## Caveats

- **One container per project.** A second `start-docker.sh` joins the running container; its sessions end when the first command exits.
- **One JDK.** The image has only the JDK set by `JDK_VERSION`. A project that needs a different version needs a rebuild with another value.
- **PostgreSQL is pinned to version 18.** Data written by one major version cannot be opened by another. Before changing the version in `compose.yml`, export the data or run `remove-docker.sh`.
- **The `postgres` image stays on disk** after `remove-docker.sh`, because other projects share it. Remove it by hand with `docker image rm postgres:18` when no project needs it.
- **Host git settings can misfire.** Commit signing, a custom editor or pager and credential helpers rely on programs and keys the container doesn't have. Override them inside with `git config --global`, for example `git config --global commit.gpgsign false`; that is stored in the `home` volume.
- **UID is baked into the image.** Rebuild if your `id -u` changes.
