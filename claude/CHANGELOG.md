# Changelog

## Version 5

* pandas and matplotlib are part of the image, for working with data and drawing charts. They are installed in the system's Python instead of the `home` volume, so a new volume, such as after `remove-docker.sh`, has them too. A copy that pip installed into `~/.local` earlier still comes first.

## Version 4

* Ubuntu instead of Alpine, with Python 3.12 (pip and venv), uv and Node.js 26 with npm, so Claude can run scripts, install the packages they need and start MCP servers. `pip install` and `npm install -g` work without root, and what they install stays in the `home` volume. The GNU versions of grep, sed and find come with it, and jq, zip, unzip, file and ps.
* Claude Code is installed in the home directory and runs from the new `home` volume, where it updates itself; a rebuild no longer resets it. The login and history move with it, so a project set up with an earlier version logs in again. The README says how to delete the old `claude-home` volume.
* The container runs in this machine's time zone instead of UTC: `start-docker.sh` passes `TZ`, or the zone `/etc/localtime` points to.
* `start-docker.sh` passes its arguments to Claude Code, such as `--continue` or `--resume`, and mounts your git config read-only.
* `build-docker.sh` uses Docker's cache again. Extra arguments, such as `--pull --no-cache`, go to `docker compose build`.
* The container runs an init process, which cleans up the processes background commands leave behind.
* A project folder whose name has a dot or another character a compose project name can't hold, such as `example.com`, works: those characters become a dash. Names that worked before stay the same.

## Version 3

* Run the scripts as yourself: they call `sudo docker` on their own when your user can't reach the Docker daemon. Running a script under `sudo` still works; before, that built the image for UID/GID 0 and failed with `addgroup: gid '0' in use`.
* `start-docker.sh` passes the terminal's color support into the container. Claude Code no longer falls back to 16 colors, which made its gray text unreadable on a light background.
* `CLAUDE_HOST_UID` and `CLAUDE_HOST_GID` are gone. The image always gets the UID/GID of the user who runs the build.

## Version 2

* Changed the build script to add `--no-cache` to be able to download the latest version of Claude Code.  
  Otherwise the version would be stuck to the version that was build into the (first) created Docker image.

## Version 1

* inital version

