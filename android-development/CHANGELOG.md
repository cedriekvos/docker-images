# Changelog

## Version 4

* The README recommends keeping the debug signing key in the project, at `keystore/debug.keystore`, so that `remove-docker.sh` no longer leads to a new key and a reinstall that deletes the app's data.
* The comments in `compose.yml` and `remove-docker.sh` say the debug keystore in the home volume only matters for projects without their own key.

## Version 3

* `start-docker.sh` passes the terminal's color support into the container. Claude Code no longer falls back to 16 colors, which made its gray text unreadable on a light background.

## Version 2

* Git now comes from the Ubuntu Git maintainers' archive, so the image has a current Git instead of Ubuntu's 2.43.
* `start-docker.sh` mounts the host's `~/.config/git/config` read-only into the container.
* `remove-docker.sh` also removes the project's container and the untagged images left by earlier builds.

## Version 1

* Initial version: JDK, Android SDK, Gradle and Claude Code on an Ubuntu base.
