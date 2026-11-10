# Changelog

## Version 2

* The ports on this machine are settings: `PHP_DEV_HTTP_PORT` and `PHP_DEV_DB_PORT` in a `.env` next to `compose.yml`, copied from the new `.env.example`. Several projects can run at once without editing `compose.yml`. A new `.gitignore` keeps `.env` out of git.
* `PHP_DEV_PROJECT_ID` can be kept in `.env` too. The scripts stop when the project's name already belongs to a project in another directory, instead of joining that project's container or, in `remove-docker.sh`, deleting its database.
* A project folder whose name has a dot or another character a compose project name can't hold, such as `example.com`, works: those characters become a dash. Names that worked before stay the same.
* Composer follows the newest 2.x release (`COMPOSER_VERSION=latest-2.x`) and updates with every build; an exact version still pins it.
* nginx has no 1 MB upload limit of its own any more, and looks PHP-FPM up while it runs, so a rebuilt fpm container no longer leads to "502 Bad Gateway".
* `php.ini` reports every error, deprecations included (`error_reporting = E_ALL`), and runs `assert()` (`zend.assertions = 1`).
* The README explains how PHP, Composer and Git are updated and how to move the database to another PostgreSQL version.

## Version 1

* Initial version: PHP, Composer and Claude Code on an Ubuntu base. nginx with PHP-FPM serves the application, and a PostgreSQL 18 database runs next to the container.
