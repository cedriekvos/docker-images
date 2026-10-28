# `php-development` container

A self-contained, per-project Docker setup for PHP development with Claude Code. The image carries PHP, Composer and Claude Code, so installing dependencies and running tests happen inside the container. nginx with PHP-FPM serves the application, and a PostgreSQL database runs next to it. The host only needs Docker.

## Layout

```
docker/php-development/
├── Dockerfile       # Ubuntu + PHP + PHP-FPM + Composer + Claude Code, non-root user matching host UID/GID
├── compose.yml      # the `php` service (one-shot, --rm on exit), nginx, PHP-FPM and a PostgreSQL database
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

Run the scripts as yourself. They call `sudo docker` on their own when your user is not allowed to talk to the Docker daemon.

## What is in the image

Versions are build arguments. Change the defaults in the `Dockerfile`, or pass `--build-arg NAME=value` to `build-docker.sh`.

| Build arg | Default | Sets |
|---|---|---|
| `PHP_VERSION` | `8.5` | PHP (`php`, `php-fpm`) and its extensions |
| `COMPOSER_VERSION` | `2.10.3` | Composer (`composer`) |

Besides what PHP has built in, the image has these extensions: bcmath, curl, gd, imagick, intl, mbstring, mysqli and pdo_mysql, PCOV, pgsql and pdo_pgsql, pdo_sqlite, readline, the XML ones (dom, simplexml, xmlreader, xmlwriter, xsl), zip and Xdebug. That covers what Laravel and Symfony ask for.

imagick handles JPEG, PNG, GIF, WebP and TIFF, and reads HEIC and AVIF but can't write them. PDF and PostScript need Ghostscript, which isn't installed. `php -m` lists everything that is loaded. For another extension, add its package to the `apt-get install` line in the `Dockerfile`, for example `"php${PHP_VERSION}-redis"`, and rebuild.

PHP comes from Ondřej Surý's archive (`ppa:ondrej/php`), because Ubuntu itself stops at PHP 8.3. Git comes from the Ubuntu Git maintainers' archive rather than from Ubuntu itself.

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

Port 8000 is published on this machine only, not to the rest of the network. Only one project can hold it at a time, and a web server that is still running from another project counts: stop that one first, or give this project another host port in `compose.yml`, for example `127.0.0.1:8001:80`.

A server of your own that runs in the session's container, such as a WebSocket server, gets its port under the `php` service in `compose.yml`:

```yaml
    ports:
      - "127.0.0.1:8080:8080"
```

`start-docker.sh` publishes the listed ports when it starts the container. The server has to listen on `0.0.0.0`, not on the container's own localhost.

## PHP settings

`php.ini` holds the project's PHP settings, such as `memory_limit` or `upload_max_filesize`. Both containers read it: the `php` container for `php`, Composer and tests, the `fpm` container for web requests. It comes after the image's own `php.ini`, which has PHP's production defaults, so a setting in it wins. `php --ini` lists the files PHP reads, `php -i` the values in effect.

A change reaches the `php` container at the next session, and the `fpm` container after `docker restart webshop-php-development-fpm-1`. Settings for web requests only, such as showing errors in the page, are in `php-fpm.conf`.

## Database

A PostgreSQL 18 server starts together with the first session. The database, the user and the password are all called `dev`.

| From | Host | Port |
|---|---|---|
| The application, inside the `php` and `fpm` containers | `db` | `5432` |
| A database GUI on this machine (TablePlus, DataGrip, DBeaver, …) | `localhost` | `5432` |

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

Port 5432 is published on this machine only, like port 8000. Only one project can hold it at a time, and a database that is still running from another project counts: stop that one first, or give this project another host port in `compose.yml`, for example `127.0.0.1:5433:5432`.

A project without a database can delete the `db` service, the `depends_on` block and the `db` volume from `compose.yml`.

## How it isolates per project

The scripts derive a unique compose project name from the dir above `docker/`:

```
/home/you/webshop/docker/php-development/  →  webshop-php-development
```

That name covers the containers, the image, the network and the volumes, so two projects don't share login state, caches or data. If two projects share a basename, set `PHP_DEV_PROJECT_ID` before running the scripts.

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
- **Composer is pinned.** `composer self-update` fails, because the image's copy belongs to root. Rebuild with another `COMPOSER_VERSION` instead.
- **PostgreSQL is pinned to version 18.** Data written by one major version cannot be opened by another. Before changing the version in `compose.yml`, export the data or run `remove-docker.sh`.
- **The `postgres` and `nginx` images stay on disk** after `remove-docker.sh`, because other projects share them. Remove them by hand with `docker image rm postgres:18 nginx:1.30` when no project needs them.
- **Host git settings can misfire.** Commit signing, a custom editor or pager and credential helpers rely on programs and keys the container doesn't have. Override them inside with `git config --global`, for example `git config --global commit.gpgsign false`; that is stored in the `home` volume.
- **UID is baked into the image.** Rebuild if your `id -u` changes.
