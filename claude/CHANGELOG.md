# Changelog

## Version 3

* Run the scripts as yourself: they call `sudo docker` on their own when your user can't reach the Docker daemon. Running a script under `sudo` still works; before, that built the image for UID/GID 0 and failed with `addgroup: gid '0' in use`.
* `start-docker.sh` passes the terminal's color support into the container. Claude Code no longer falls back to 16 colors, which made its gray text unreadable on a light background.
* `CLAUDE_HOST_UID` and `CLAUDE_HOST_GID` are gone. The image always gets the UID/GID of the user who runs the build.

## Version 2

* Changed the build script to add `--no-cache` to be able to download the latest version of Claude Code.  
  Otherwise the version would be stuck to the version that was build into the (first) created Docker image.

## Version 1

* inital version

