# Changelog

## Version 3

* A PostgreSQL 18 database now runs next to the Java container. The application reaches it as host `db`, and a database GUI on the host reaches it at `localhost:5432`.

## Version 2

* `start-docker.sh` passes the terminal's color support into the container. Claude Code no longer falls back to 16 colors, which made its gray text unreadable on a light background.

## Version 1

* Initial version: JDK, Maven, Gradle and Claude Code on an Ubuntu base.
