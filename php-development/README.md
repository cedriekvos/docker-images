# `php-development` container

A self-contained, per-project Docker setup for PHP development with Claude Code. The image carries PHP, Composer and Claude Code, so installing dependencies and running tests happen inside the container. nginx with PHP-FPM serves the application, and a PostgreSQL database runs next to it. The host only needs Docker.

## Layout

```
docker/php-development/
├── Dockerfile       # Ubuntu + PHP + PHP-FPM + Composer + Claude Code, non-root user matching host UID/GID
├── compose.yml      # the `php` service (one-shot, --rm on exit), nginx, PHP-FPM and a PostgreSQL database
├── .env.example     # this project's ports and name on this machine; copy it to .env to change them
├── .gitignore       # keeps .env out of git
├── nginx.conf       # the site: serves public/, hands PHP to PHP-FPM
├── php-fpm.conf     # PHP-FPM: runs as you, with development settings
├── php.ini          # PHP settings for the command line and PHP-FPM alike
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
docker/php-development/bin/build-docker.sh

# Launch an interactive Claude session in the project root
docker/php-development/bin/start-docker.sh

# While that session runs: a shell or a one-off command in the same container
docker/php-development/bin/start-docker.sh bash
docker/php-development/bin/start-docker.sh composer install

# Tear everything down (deletes login, history, the Composer cache and the database!)
docker/php-development/bin/remove-docker.sh
```

Run the scripts as yourself. They call `sudo docker` on their own when your user is not allowed to talk to the Docker daemon. The other `docker` commands in this README need `sudo` in front in that case.

## What is in the image

Versions are build arguments. Change the defaults in the `Dockerfile`, or pass `--build-arg NAME=value` to `build-docker.sh`.

| Build arg | Default | Sets |
|---|---|---|
| `PHP_VERSION` | `8.5` | PHP (`php`, `php-fpm`) and its extensions |
| `COMPOSER_VERSION` | `latest-2.x` | Composer (`composer`): the newest 2.x release. An exact version, such as `2.10.3`, pins it |

Besides what PHP has built in, the image has these extensions: bcmath, curl, gd, imagick, intl, mbstring, mysqli and pdo_mysql, PCOV, pgsql and pdo_pgsql, pdo_sqlite, readline, the XML ones (dom, simplexml, xmlreader, xmlwriter, xsl), zip and Xdebug. That covers what Laravel and Symfony ask for.

imagick handles JPEG, PNG, GIF, WebP and TIFF, and reads HEIC and AVIF but can't write them. PDF and PostScript need Ghostscript, which isn't installed. `php -m` lists everything that is loaded. For another extension, add its package to the `apt-get install` line in the `Dockerfile`, for example `"php${PHP_VERSION}-redis"`, and rebuild.

PHP comes from Ondřej Surý's archive (`ppa:ondrej/php`), because Ubuntu itself stops at PHP 8.3. Git comes from the Ubuntu Git maintainers' archive rather than from Ubuntu itself.

## PHP, Composer and Git updates

PHP, Composer and Git are part of the image, so they change with a rebuild only.

- **Composer** gets its newest 2.x release at every `build-docker.sh`.
- **PHP and Git** come from apt. Docker reuses its earlier result of that step for as long as the step in the `Dockerfile` stays the same, so a plain rebuild keeps the versions you have. Rebuild without the cache to get their newest releases, together with a newer Ubuntu base and its security updates:

  ```sh
  docker/php-development/bin/build-docker.sh --pull --no-cache
  ```

- **Another PHP version**, such as 8.4: change `PHP_VERSION` in the `Dockerfile` and rebuild. A `--build-arg` lasts for one build only; the next plain build goes back to the version in the `Dockerfile`.

The next session runs in the new image, and PHP-FPM should be recreated from it when that session starts. Check that the two have the same PHP: `php -v` in a session, and from this machine

```sh
docker exec webshop-php-development-fpm-1 php -v
```

If PHP-FPM still has the old version, remove its container with `docker rm --force webshop-php-development-fpm-1`; the next session starts a new one.

## Claude Code updates

Claude Code is installed in the home directory, so the copy that runs lives in the `home` volume and updates itself there. An update that was downloaded during a session takes effect at the next start.

Docker fills the volume from the image only once, when the volume is new. Rebuilding the image afterwards does not change Claude Code in an existing project. If an update ever goes wrong, open a shell with `start-docker.sh bash` and run `claude update`, or reinstall with `curl -fsSL https://claude.ai/install.sh | bash`.

## Starting a new project

`composer init` writes a `composer.json` into the project root. A framework skeleton comes from `composer create-project`, which wants an empty directory, and the project root already holds `docker/`. Create the skeleton in a subdirectory and move it up:

```sh
composer create-project laravel/laravel tmp      # or symfony/skeleton
cp -a tmp/. . && rm -rf tmp
```

`cp` overwrites files of the same name in the project root, such as a `README.md` or `.gitignore`. You can also ask Claude to scaffold the project.

## Code coverage

PCOV measures code coverage. PHPUnit and Pest use it on their own when asked for a report:

```sh
vendor/bin/phpunit --coverage-text
php artisan test --coverage
```

PCOV measures the first of `src/`, `lib/` and `app/` it finds in the directory the tests run from, which fits Laravel and Symfony. For code elsewhere, set `pcov.directory` in `php.ini`. `compose.yml` turns PCOV off in PHP-FPM, because for web requests it only costs time.

Xdebug is installed too, for branch and path coverage, which PCOV can't measure. It slows PHP down and can't run alongside PCOV, so `php.ini` turns it off. A command that needs it turns it on and PCOV off, for itself only:

```sh
XDEBUG_MODE=coverage php -d pcov.enabled=0 vendor/bin/phpunit --path-coverage --coverage-text
```

## Web server

nginx serves the application at `http://localhost:8000`. It starts together with the first session, with PHP-FPM behind it, and both keep running after the session ends, like the database.

nginx serves the project's `public/` directory. Files that exist there come straight from nginx, `.php` files run in PHP-FPM, and every other path goes to `public/index.php`, the front controller of Laravel and Symfony. For a project with another document root, change `root` in `nginx.conf`.

PHP-FPM is built from the same `Dockerfile` as the session's container, so it has the same PHP and extensions. It runs as you: files the application writes, such as logs and caches, belong to you. `php-fpm.conf` turns on two settings for development: errors show in the page, and a change to the code shows on the next request.

The two configuration files are read when their container starts. After editing one, restart that container. Its name is the project name from [How it isolates per project](#how-it-isolates-per-project) plus `-nginx-1` or `-fpm-1`:

```sh
docker restart webshop-php-development-nginx-1
docker restart webshop-php-development-fpm-1
```

`docker logs` on the same names shows the requests and PHP's errors, and so does a tool such as lazydocker.

Port 8000 is published on this machine only, not to the rest of the network. Only one project can hold it at a time, and a web server that is still running from another project counts. [Running several projects at once](#running-several-projects-at-once) gives a project another port.

A server of your own that runs in the session's container, such as a WebSocket server, gets its port under the `php` service in `compose.yml`:

```yaml
    ports:
      - "127.0.0.1:8080:8080"
```

`start-docker.sh` publishes the listed ports when it starts the container. The server has to listen on `0.0.0.0`, not on the container's own localhost. Such a port, too, can only be held by one project at a time; [Running several projects at once](#running-several-projects-at-once) shows how to make it a setting.

## PHP settings

`php.ini` holds the project's PHP settings, such as `memory_limit` or `upload_max_filesize`. Both containers read it: the `php` container for `php`, Composer and tests, the `fpm` container for web requests. It comes after the image's own `php.ini`, which has PHP's production defaults, so a setting in it wins. `php --ini` lists the files PHP reads, `php -i` the values in effect.

Two of those defaults hide problems during development, so `php.ini` changes them to PHP's development values. `error_reporting = E_ALL` reports deprecations too, which production leaves out. `zend.assertions = 1` makes `assert()` run; in production it is left out when the code is compiled, and a script can't turn it back on.

nginx has no upload limit of its own, so `upload_max_filesize` and `post_max_size` decide how large an upload can be.

A change reaches the `php` container at the next session, and the `fpm` container after `docker restart webshop-php-development-fpm-1`. Settings for web requests only, such as showing errors in the page, are in `php-fpm.conf`.

## Database

A PostgreSQL 18 server starts together with the first session. The database, the user and the password are all called `dev`.

| From | Host | Port |
|---|---|---|
| The application, inside the `php` and `fpm` containers | `db` | `5432` |
| A database GUI on this machine (TablePlus, DataGrip, DBeaver, …) | `localhost` | `5432`, or the port in `.env` |

For Laravel, in `.env`:

```dotenv
DB_CONNECTION=pgsql
DB_HOST=db
DB_PORT=5432
DB_DATABASE=dev
DB_USERNAME=dev
DB_PASSWORD=dev
```

For Symfony, in `.env.local`:

```dotenv
DATABASE_URL="postgresql://dev:dev@db:5432/dev?serverVersion=18&charset=utf8"
```

The database keeps running after the session ends, so a GUI can stay connected, and the next `start-docker.sh` reuses it. Stop it with `docker stop` or a tool such as lazydocker when you don't need it. Its data lives in the `db` volume: it survives sessions, stops and rebuilds, and is erased by `remove-docker.sh`.

Port 5432 is published on this machine only, like port 8000. Only one project can hold it at a time, and a database that is still running from another project counts. [Running several projects at once](#running-several-projects-at-once) gives a project another port; the application inside keeps using `db:5432`.

A project without a database can delete the `db` service, the `depends_on` block and the `db` volume from `compose.yml`.

### Moving to another PostgreSQL version

Data written by one major version of PostgreSQL can't be opened by another, so the data moves over in an SQL dump. Take the dump while the old version still runs, then remove its container and data:

```sh
docker exec webshop-php-development-db-1 pg_dump --username=dev dev > dump.sql
docker rm --force webshop-php-development-db-1
docker volume rm webshop-php-development_db
```

Change the `postgres` image in `compose.yml` and start a session, which creates the new server with an empty database. Load the dump into it:

```sh
docker exec -i webshop-php-development-db-1 psql --username=dev dev < dump.sql
```

## How it isolates per project

The scripts derive a unique compose project name from the dir above `docker/`:

```
/home/you/webshop/docker/php-development/  →  webshop-php-development
```

That name covers the containers, the image, the network and the volumes, so two projects don't share login state, caches or data. The name is lowercased, and characters a compose project name can't hold, such as spaces, underscores or the dot in `example.com`, become dashes.

Two projects with the same folder name, such as `~/work/api` and `~/personal/api`, would get the same name, and with it each other's containers and volumes. The scripts check for that: when the name's containers belong to a project in another directory, they stop and say so. Give one of the two its own name in `.env` next to `compose.yml` (copy `.env.example`, as in [Running several projects at once](#running-several-projects-at-once)):

```dotenv
PHP_DEV_PROJECT_ID=personal-api-php-development
```

Set it before the project's first start. A project that changes its name later starts over with an empty database and a new Claude login; the old ones stay behind under the old name. A `PHP_DEV_PROJECT_ID` set in the shell wins over the one in `.env`.

## Running several projects at once

Several projects can run side by side, each with its own containers, network and volumes. What they share is this machine's ports: nginx publishes 8000 and the database 5432, and only one project can hold a port at a time. nginx and the database keep running after a session ends, so a project you worked on earlier still holds them, and starting another one fails with `port is already allocated`.

To give a project other ports, copy `.env.example` to `.env` in the same directory:

```sh
cp docker/php-development/.env.example docker/php-development/.env
```

Then change the ports in `.env`, for example:

```dotenv
PHP_DEV_HTTP_PORT=8001
PHP_DEV_DB_PORT=5433
```

That project's application is then at `http://localhost:8001`, and a database GUI connects to `localhost:5433`. Inside Docker nothing changes: the application still reaches the database at `db:5432`. This `.env` is not the application's own `.env` in the project root; Docker Compose and the scripts read this one, and the application never sees it.

The ports apply from the next session on: when it starts, nginx and the database are recreated with the new ports. The database keeps its data, which lives in its volume.

`.env` stays on this machine: the `.gitignore` in this directory keeps it out of git, because which ports are free depends on what else runs on the machine. `.env.example` is committed with the project.

Set the ports in the file, not as shell variables. The scripts call `sudo docker` when your user can't reach the Docker daemon, and sudo doesn't pass shell variables on.

A port of your own under the `php` service, such as the WebSocket server's in [Web server](#web-server), can be a setting the same way. Write it as `"127.0.0.1:${PHP_DEV_WS_PORT:-8080}:8080"` in `compose.yml` and put `PHP_DEV_WS_PORT=8081` in `.env`. Add it to `.env.example` too, with its default, so the next person to copy that file finds it.

## What gets mounted

| Host | Container | Why |
|---|---|---|
| `../..` (the project root containing `docker/`) | `/workspace`, read-only in the `nginx` container | Your code, live |
| `home` (named volume) | `/home/dev` | Claude Code with its login + history, the Composer cache |
| `~/.config/git/config` | `/etc/gitconfig` (read-only) | Your git name, email and settings; added by `start-docker.sh` when the file exists |
| `nginx.conf` | `/etc/nginx/conf.d/default.conf` in the `nginx` container (read-only) | The site nginx serves |
| `php-fpm.conf` | `/etc/php-fpm.conf` in the `fpm` container (read-only) | PHP-FPM's settings |
| `php.ini` | `/etc/php/project.ini` in the `php` and `fpm` containers (read-only) | PHP settings for both |
| `db` (named volume) | `/var/lib/postgresql` in the `db` container | The database's data |

## Not included

- **An IDE.** No step debugger or profiler. Xdebug is only set up for coverage; step debugging needs an IDE on the host that listens for it. Everything goes through Composer, the test runner and Claude.
- **Node.js.** Frontend assets built with npm and Vite, as in a default Laravel application, can't be built here.
- **HTTPS.** nginx serves plain HTTP.
- **Docker inside the container.** Tests that start containers themselves cannot run here. Point them at the `db` service instead.
- **Other services.** PostgreSQL is the only one set up; there is no Redis, message broker or mail server.
- **Git credentials.** Commits made in the container carry your name and email, but there are no SSH keys or tokens inside. Push from the host.

## Caveats

- **One container per project.** A second `start-docker.sh` joins the running container; its sessions end when the first command exits.
- **One PHP version.** The image has only the PHP set by `PHP_VERSION`, and the session and PHP-FPM share it. A project that needs a different version needs a rebuild with another value.
- **Composer updates with a rebuild.** `composer self-update` fails, because the image's copy belongs to root. Instead, every `build-docker.sh` checks for a newer 2.x release and takes it, so a build needs a connection to getcomposer.org. Version 3 won't come in on its own: when it is out, change `COMPOSER_VERSION` in the `Dockerfile`. See [PHP, Composer and Git updates](#php-composer-and-git-updates).
- **PostgreSQL is pinned to version 18.** Data written by one major version cannot be opened by another. Before changing the version in `compose.yml`, follow [Moving to another PostgreSQL version](#moving-to-another-postgresql-version).
- **The `postgres` and `nginx` images stay on disk** after `remove-docker.sh`, because other projects share them. Remove them by hand with `docker image rm postgres:18 nginx:1.30` when no project needs them.
- **Host git settings can misfire.** Commit signing, a custom editor or pager and credential helpers rely on programs and keys the container doesn't have. Override them inside with `git config --global`, for example `git config --global commit.gpgsign false`; that is stored in the `home` volume.
- **UID is baked into the image.** Rebuild if your `id -u` changes.
