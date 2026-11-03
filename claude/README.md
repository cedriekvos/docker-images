# `claude` container

A self-contained, per-project Docker setup for running Claude Code interactively. **Independent of SwarmForge** — use this when you just want a sandboxed `claude` session that lives alongside your project.

## Layout

```
docker/claude/
├── Dockerfile       # Alpine + Claude Code, non-root user matching host UID/GID
├── compose.yml      # one service: `claude` (one-shot, --rm on exit)
├── README.md
└── bin/
    ├── build-docker.sh     # build the image
    ├── start-docker.sh     # run `claude` interactively, ephemeral container
    ├── remove-docker.sh    # tear down image + named volume
    └── _common.sh          # shared by the three scripts
```

## Usage

```sh
# Build once (or after editing the Dockerfile)
docker/claude/bin/build-docker.sh

# Launch an interactive Claude session in the project root
docker/claude/bin/start-docker.sh

# Tear everything down (deletes login + history!)
docker/claude/bin/remove-docker.sh
```

Run the scripts as yourself. They call `sudo docker` on their own when your user is not allowed to talk to the Docker daemon.

## How it isolates per project

When you copy this folder into a project, the bin scripts automatically derive a unique compose project name from the dir above `docker/`:

```
/home/you/web-app/docker/claude/   →  CLAUDE_PROJECT_ID=web-app-claude
/home/you/data-tool/docker/claude/ →  CLAUDE_PROJECT_ID=data-tool-claude
```

That namespace covers the compose project, the network, and the `claude-home` named volume — so two projects' Claude sessions don't share login state or clobber each other.

If two projects share a basename (e.g. `~/work/api` and `~/personal/api`), set `CLAUDE_PROJECT_ID` manually before running the scripts.

## Environment variables

| Variable | Default | Effect |
|---|---|---|
| `CLAUDE_PROJECT_ID` | `<project-basename>-claude` | Namespaces compose project / network / `claude-home` volume |

## What gets mounted

| Host | Container | Why |
|---|---|---|
| `../..` (the project root containing `docker/`) | `/workspace` | Your code, live |
| `claude-home` (named volume) | `/claude-home` | Login + settings + per-cwd conversation history, survives container restarts |

## Caveats

- **Login is per-project** by design. First `start-docker.sh` in a new project will prompt for auth.
- **UID is baked into the image.** Rebuild if your `id -u` changes.
- **One-shot only.** `start-docker.sh` does `docker compose run --rm`, so each invocation is a fresh container. The volume keeps state between runs; the container itself doesn't.
- **No relation to `docker/swarmforge-sail/`.** They share zero state — different volumes, different project namespaces, different purposes. This one is for personal interactive sessions; that one is for SwarmForge agent orchestration via Sail.
