# `claude` container

A self-contained, per-project Docker setup for running Claude Code interactively: a sandboxed `claude` session that lives alongside your project.

## Layout

```
docker/claude/
├── Dockerfile       # Alpine + Claude Code, non-root user matching host UID/GID
├── compose.yml      # one service: `claude` (one-shot, --rm on exit)
├── README.md
└── bin/
    ├── build-docker.sh     # build the image
    ├── start-docker.sh     # run `claude` interactively, ephemeral container; arguments go to claude
    ├── remove-docker.sh    # tear down image + named volume
    └── _common.sh          # shared by the three scripts
```

## Usage

```sh
# Build once (or after editing the Dockerfile)
docker/claude/bin/build-docker.sh

# Launch an interactive Claude session in the project root
docker/claude/bin/start-docker.sh

# Arguments go to Claude Code: continue the last conversation, or pick one
docker/claude/bin/start-docker.sh --continue
docker/claude/bin/start-docker.sh --resume

# Tear everything down (deletes login + history!)
docker/claude/bin/remove-docker.sh
```

Run the scripts as yourself. They call `sudo docker` on their own when your user is not allowed to talk to the Docker daemon. The other `docker` commands in this README need `sudo` in front in that case.

## Claude Code updates

Claude Code is installed in the home directory, so the copy that runs lives in the `home` volume and updates itself there. An update that was downloaded during a session takes effect at the next start.

Docker fills the volume from the image only once, when the volume is new. Rebuilding the image afterwards does not change Claude Code in an existing project. If an update ever goes wrong, start over with `remove-docker.sh` and `build-docker.sh --no-cache`: the new volume gets the latest Claude Code, and you log in again.

## Projects set up before version 4

Up to version 3, the login and history lived in a volume called `claude-home`. Version 4 keeps them in the new `home` volume instead, so a project that used an earlier version starts fresh: you log in again at the first start, and earlier conversations don't show up in `--resume`.

The old volume stays behind, and `remove-docker.sh` no longer knows about it. Delete it by hand. Its name is the project name from [How it isolates per project](#how-it-isolates-per-project) plus `_claude-home`:

```sh
docker volume ls --filter name=claude-home    # lists the old volumes of all projects
docker volume rm web-app-claude_claude-home
```

## How it isolates per project

When you copy this folder into a project, the bin scripts automatically derive a unique compose project name from the dir above `docker/`:

```
/home/you/web-app/docker/claude/   →  CLAUDE_PROJECT_ID=web-app-claude
/home/you/data-tool/docker/claude/ →  CLAUDE_PROJECT_ID=data-tool-claude
```

That namespace covers the compose project, the network, and the `home` named volume — so two projects' Claude sessions don't share login state or clobber each other. The name is lowercased, and characters a compose project name can't hold, such as spaces, underscores or the dot in `example.com`, become dashes.

If two projects share a basename (e.g. `~/work/api` and `~/personal/api`), set `CLAUDE_PROJECT_ID` manually before running the scripts.

## Environment variables

| Variable | Default | Effect |
|---|---|---|
| `CLAUDE_PROJECT_ID` | `<project-basename>-claude` | Namespaces compose project / network / `home` volume |

## What gets mounted

| Host | Container | Why |
|---|---|---|
| `../..` (the project root containing `docker/`) | `/workspace` | Your code, live |
| `home` (named volume) | `/home/claude` | Claude Code with its login, settings and per-cwd conversation history; survives container restarts |
| `~/.config/git/config` | `/etc/gitconfig` (read-only) | Your git name, email and settings; added by `start-docker.sh` when the file exists |

## Caveats

- **Login is per-project** by design. First `start-docker.sh` in a new project will prompt for auth.
- **UID is baked into the image.** Rebuild if your `id -u` changes.
- **One-shot only.** `start-docker.sh` does `docker compose run --rm`, so each invocation is a fresh container. The volume keeps state between runs; the container itself doesn't.
- **No git credentials.** Commits made in the container carry your name and email, but there are no SSH keys or tokens inside. Push from the host.
- **Host git settings can misfire.** Commit signing, a custom editor or pager and credential helpers rely on programs and keys the container doesn't have. Override them inside with `git config --global`, for example `git config --global commit.gpgsign false`; that is stored in the `home` volume.
