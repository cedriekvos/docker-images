# Changelog

## Version 3

* `start-docker.sh` passes the terminal's color support into the container. Claude Code no longer falls back to 16 colors, which made its gray text unreadable on a light background.

## Version 2

* Git now comes from the Ubuntu Git maintainers' archive, so the image has a current Git instead of Ubuntu's 2.43.
* `start-docker.sh` mounts the host's `~/.config/git/config` read-only into the container.
* `remove-docker.sh` also removes the project's container and the untagged images left by earlier builds.

## Version 1

* Initial version: JDK, Android SDK, Gradle and Claude Code on an Ubuntu base.
