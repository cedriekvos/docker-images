# `shopware-development` container

A self-contained, per-project Docker setup for Shopware 6 development with Claude Code. The image carries PHP, Composer, Node.js and Claude Code, so installing the shop, building its JavaScript and running tests happen inside the container. nginx with PHP-FPM serves the shop, a MySQL database runs next to it, and Mailpit catches the mails it sends. The host only needs Docker.

It is the `php-development` setup changed for Shopware: MySQL instead of PostgreSQL, Node.js for the JavaScript builds, PHP settings with room for Shopware, and nginx set up like Shopware's own configuration.

## Layout

```
docker/shopware-development/
├── Dockerfile       # Ubuntu + PHP + PHP-FPM + Composer + Node.js + Claude Code, non-root user matching host UID/GID
├── compose.yml      # the `php` service (one-shot, --rm on exit), nginx, PHP-FPM, a MySQL database and Mailpit
├── .env.example     # this project's ports and name on this machine; copy it to .env to change them
├── .gitignore       # keeps .env out of git
├── nginx.conf       # the shop: serves public/, hands PHP to PHP-FPM
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
docker/shopware-development/bin/build-docker.sh

# Launch an interactive Claude session in the project root
docker/shopware-development/bin/start-docker.sh

# While that session runs: a shell or a one-off command in the same container
docker/shopware-development/bin/start-docker.sh bash
docker/shopware-development/bin/start-docker.sh bin/console cache:clear

# Tear everything down (deletes login, history, the Composer and npm caches and the database!)
docker/shopware-development/bin/remove-docker.sh
```

Run the scripts as yourself. They call `sudo docker` on their own when your user is not allowed to talk to the Docker daemon. The other `docker` commands in this README need `sudo` in front in that case.

## What is in the image

Versions are build arguments. Change the defaults in the `Dockerfile`, or pass `--build-arg NAME=value` to `build-docker.sh`.

| Build arg | Default | Sets |
|---|---|---|
| `PHP_VERSION` | `8.5` | PHP (`php`, `php-fpm`) and its extensions |
| `NODE_VERSION` | `22` | Node.js (`node`, `npm`): the newest release of that major version |
| `COMPOSER_VERSION` | `latest-2.x` | Composer (`composer`): the newest 2.x release. An exact version, such as `2.10.3`, pins it |

Shopware 6.7.12 and later are tested with PHP 8.5. An older shop needs an older PHP: 8.4 for an earlier 6.7, 8.3 for 6.6. When PHP doesn't fit, `composer install` stops with a message about the PHP version; change `PHP_VERSION` and rebuild, as in [PHP, Composer, Node.js and Git updates](#php-composer-nodejs-and-git-updates).

Besides what PHP has built in, the image has the extensions Shopware asks for: curl, gd, intl, mbstring, mysqli and pdo_mysql, the XML ones (dom, simplexml, xmlreader, xmlwriter, xsl), zip, and fileinfo, iconv, phar and sodium, which come with PHP's base package. OPcache keeps Shopware's PHP compiled; from PHP 8.5 on it is part of PHP itself, and for an older PHP the image installs it as a package. bcmath, readline, PCOV and Xdebug are there too. The build checks Shopware's list and stops when an extension is missing. `php -m` lists everything that is loaded. For another extension, add its package to the `apt-get install` line in the `Dockerfile`, for example `"php${PHP_VERSION}-redis"`, and rebuild.

Node.js comes from NodeSource's archive, because Ubuntu's own is version 18 and Shopware 6.7 asks for 20 or newer. npm comes with it. jq is there for Shopware's build scripts, which use it to find the extensions whose JavaScript needs npm packages of its own.

PHP comes from Ondřej Surý's archive (`ppa:ondrej/php`), because Ubuntu itself stops at PHP 8.3. Git comes from the Ubuntu Git maintainers' archive rather than from Ubuntu itself.

## Starting a new shop

`composer create-project` wants an empty directory, and the project root already holds `docker/`. Create the shop in a subdirectory and move it up:

```sh
SYMFONY_DOCKER=0 composer create-project shopware/production tmp
cp -a tmp/. . && rm -rf tmp var/cache
```

`var/cache` goes because it holds the paths of `tmp/`; Shopware fills it again on the next request. `cp` overwrites files of the same name in the project root, such as a `README.md` or `.gitignore`.

`SYMFONY_DOCKER=0` keeps Symfony Flex from adding Docker files of its own, such as a `compose.yaml` in the project root: this folder is the Docker setup. Flex asks about them in a terminal only; without one, as when Claude runs Composer, it adds them without asking. The variable answers "no" for good: Flex stores `"docker": false` in `composer.json`, so packages added later don't bring Docker files either.

Then tell Shopware where it runs, in `.env.local` in the project root:

```dotenv
APP_ENV=dev
APP_URL=http://localhost:8000
DATABASE_URL=mysql://root:root@db:3306/shopware
MAILER_DSN=smtp://mailpit:1025
```

And install it:

```sh
bin/console system:install --basic-setup --create-database
```

`--basic-setup` creates an admin user and a Storefront sales channel at `APP_URL`. The Storefront is at `http://localhost:8000`, and the Administration at `http://localhost:8000/admin`, user `admin`, password `shopware`.

You can also ask Claude to set the shop up.

## Working on an existing shop

Install its packages with `composer install` and write the `.env.local` from [Starting a new shop](#starting-a-new-shop). Load its database from a dump, as in [Database](#database).

Shopware only answers on the domains of its sales channels, so the Storefront shows an error until one of them is `APP_URL`. The Administration works on any domain: under Sales Channels, open the Storefront and add `http://localhost:8000` as a domain. The URL in the browser has to match it exactly, so `http://127.0.0.1:8000` won't do.

## JavaScript

The Administration and the Storefront come built in their Composer packages, so a shop runs without building anything. Extensions with JavaScript of their own, and changes to the JavaScript of the Administration or the Storefront, need a build:

```sh
bin/build-js.sh                 # both
bin/build-administration.sh
bin/build-storefront.sh
```

npm downloads its packages into the `home` volume, so the next build reuses them. A change to a theme's SCSS needs no Node.js: `bin/console theme:compile` compiles it in PHP.

The watchers, `bin/watch-administration.sh` and `bin/watch-storefront.sh`, don't work here as they are; see [Caveats](#caveats).

## PHP, Composer, Node.js and Git updates

PHP, Composer, Node.js and Git are part of the image, so they change with a rebuild only.

- **Composer** gets its newest 2.x release at every `build-docker.sh`.
- **PHP, Node.js and Git** come from apt. Docker reuses its earlier result of that step for as long as the step in the `Dockerfile` stays the same, so a plain rebuild keeps the versions you have. Rebuild without the cache to get their newest releases, together with a newer Ubuntu base and its security updates:

  ```sh
  docker/shopware-development/bin/build-docker.sh --pull --no-cache
  ```

- **Another PHP or Node.js version**, such as PHP 8.4: change `PHP_VERSION` or `NODE_VERSION` in the `Dockerfile` and rebuild. A `--build-arg` lasts for one build only; the next plain build goes back to the version in the `Dockerfile`.

The next session runs in the new image, and PHP-FPM should be recreated from it when that session starts. Check that the two have the same PHP: `php -v` in a session, and from this machine

```sh
docker exec webshop-shopware-development-fpm-1 php -v
```

If PHP-FPM still has the old version, remove its container with `docker rm --force webshop-shopware-development-fpm-1`; the next session starts a new one.

## Claude Code updates

Claude Code is installed in the home directory, so the copy that runs lives in the `home` volume and updates itself there. An update that was downloaded during a session takes effect at the next start.

Docker fills the volume from the image only once, when the volume is new. Rebuilding the image afterwards does not change Claude Code in an existing project. If an update ever goes wrong, open a shell with `start-docker.sh bash` and run `claude update`, or reinstall with `curl -fsSL https://claude.ai/install.sh | bash`.

## Code coverage

PCOV measures code coverage. PHPUnit uses it on its own when asked for a report:

```sh
vendor/bin/phpunit --coverage-text
```

PCOV measures the first of `src/`, `lib/` and `app/` it finds in the directory the tests run from. Run an extension's tests from its directory, such as `custom/plugins/MyPlugin`, whose code is in `src/`. For tests run from somewhere else, set `pcov.directory` in `php.ini`. `compose.yml` turns PCOV off in PHP-FPM, because for web requests it only costs time.

Xdebug is installed too, for branch and path coverage, which PCOV can't measure. It slows PHP down and can't run alongside PCOV, so `php.ini` turns it off. A command that needs it turns it on and PCOV off, for itself only:

```sh
XDEBUG_MODE=coverage php -d pcov.enabled=0 vendor/bin/phpunit --path-coverage --coverage-text
```

## Web server

nginx serves the shop at `http://localhost:8000`. It starts together with the first session, with PHP-FPM behind it, and both keep running after the session ends, like the database.

nginx serves the project's `public/` directory. Files that exist there come straight from nginx, `.php` files run in PHP-FPM, and every other path goes to `public/index.php`, Shopware's front controller, which also makes the thumbnails that don't exist yet. The rest follows Shopware's own nginx configuration: PHP in `media/`, `thumbnail/`, `theme/`, `bundles/` and `sitemap/` never runs, SVGs can't run scripts, and the buffers are large enough for the long headers of Symfony's profiler, which would otherwise end in `502 Bad Gateway`. A request may take five minutes, for indexing or compiling a theme from the Administration. Shopware's long caching headers are left out: during development they would keep a rebuilt file from showing.

PHP-FPM is built from the same `Dockerfile` as the session's container, so it has the same PHP and extensions. It runs as you: files the shop writes, such as `var/` and `public/media/`, belong to you. `php-fpm.conf` turns on two settings for development: errors show in the page, and a change to the code shows on the next request.

The two configuration files are read when their container starts. After editing one, restart that container. Its name is the project name from [How it isolates per project](#how-it-isolates-per-project) plus `-nginx-1` or `-fpm-1`:

```sh
docker restart webshop-shopware-development-nginx-1
docker restart webshop-shopware-development-fpm-1
```

`docker logs` on the same names shows the requests and PHP's errors, and so does a tool such as lazydocker. Shopware's own log is in `var/log/`.

Port 8000 is published on this machine only, not to the rest of the network. Only one project can hold it at a time, and a web server that is still running from another project counts. [Running several projects at once](#running-several-projects-at-once) gives a project another port.

A server of your own that runs in the session's container gets its port under the `php` service in `compose.yml`:

```yaml
    ports:
      - "127.0.0.1:8080:8080"
```

`start-docker.sh` publishes the listed ports when it starts the container. The server has to listen on `0.0.0.0`, not on the container's own localhost. Such a port, too, can only be held by one project at a time; [Running several projects at once](#running-several-projects-at-once) shows how to make it a setting.

## PHP settings

`php.ini` holds the project's PHP settings. Both containers read it: the `php` container for `php`, Composer, `bin/console` and tests, the `fpm` container for web requests. It comes after the image's own `php.ini`, which has PHP's production defaults, so a setting in it wins. `php --ini` lists the files PHP reads, `php -i` the values in effect.

Two of those defaults hide problems during development, so `php.ini` changes them to PHP's development values. `error_reporting = E_ALL` reports deprecations too, which production leaves out. `zend.assertions = 1` makes `assert()` run; in production it is left out when the code is compiled, and a script can't turn it back on.

For Shopware, `php.ini` gives OPcache room for Shopware's number of PHP files, and lets an upload in the Administration be up to 32 MB. nginx has no upload limit of its own, so `upload_max_filesize` and `post_max_size` decide.

`php-fpm.conf` gives a web request 512 MB, the least Shopware asks for, and five minutes. The command line keeps PHP's own defaults there: no memory limit and no time limit, for `bin/console` and Composer.

A change to `php.ini` reaches the `php` container at the next session, and the `fpm` container after `docker restart webshop-shopware-development-fpm-1`.

## Database

A MySQL 8.4 server starts together with the first session. The database is called `shopware`; the shop connects as `root`, password `root`, so it can create databases of its own, such as one for tests.

| From | Host | Port |
|---|---|---|
| The shop, inside the `php` and `fpm` containers | `db` | `3306` |
| A database GUI on this machine (TablePlus, DataGrip, DBeaver, …) | `localhost` | `3306`, or the port in `.env` |

The shop's `DATABASE_URL`, in `.env.local`:

```dotenv
DATABASE_URL=mysql://root:root@db:3306/shopware
```

New databases and tables get Shopware's collation, `utf8mb4_unicode_ci`. The binary log is off: it is for replication, and every indexing run would make it grow.

A dump of the database, and loading one, from this machine:

```sh
docker exec webshop-shopware-development-db-1 mysqldump --user=root --password=root shopware > dump.sql
docker exec -i webshop-shopware-development-db-1 mysql --user=root --password=root shopware < dump.sql
```

The database keeps running after the session ends, so a GUI can stay connected, and the next `start-docker.sh` reuses it. Stop it with `docker stop` or a tool such as lazydocker when you don't need it. Its data lives in the `db` volume: it survives sessions, stops and rebuilds, and is erased by `remove-docker.sh`.

Port 3306 is published on this machine only, like port 8000. Only one project can hold it at a time, and a database that is still running from another project counts. [Running several projects at once](#running-several-projects-at-once) gives a project another port; the shop inside keeps using `db:3306`.

### Moving to another MySQL version

A newer MySQL upgrades the data in place when it first starts on it, and the older version can't open it afterwards. Take a dump first, as above. MySQL upgrades from one LTS version to the next, such as 8.4 to 9.7, so for that step changing the `mysql` image in `compose.yml` is enough.

For a bigger step, or to go back, start over with an empty database. Remove the container and its data after the dump:

```sh
docker rm --force webshop-shopware-development-db-1
docker volume rm webshop-shopware-development_db
```

Change the `mysql` image in `compose.yml` and start a session, which creates the new server with an empty `shopware` database. Load the dump into it as above.

## Mail

Mailpit catches every mail the shop sends, such as order confirmations and password resets, and shows them at `http://localhost:8025`. Nothing leaves this machine. `MAILER_DSN=smtp://mailpit:1025` in `.env.local` sends the shop's mail there.

Mailpit starts together with the first session and keeps running afterwards. It keeps the mails in memory, so they are gone when its container restarts.

## How it isolates per project

The scripts derive a unique compose project name from the dir above `docker/`:

```
/home/you/webshop/docker/shopware-development/  →  webshop-shopware-development
```

That name covers the containers, the image, the network and the volumes, so two projects don't share login state, caches or data. The name is lowercased, and characters a compose project name can't hold, such as spaces, underscores or the dot in `example.com`, become dashes.

Two projects with the same folder name, such as `~/work/shop` and `~/personal/shop`, would get the same name, and with it each other's containers and volumes. The scripts check for that: when the name's containers belong to a project in another directory, they stop and say so. Give one of the two its own name in `.env` next to `compose.yml` (copy `.env.example`, as in [Running several projects at once](#running-several-projects-at-once)):

```dotenv
SHOPWARE_DEV_PROJECT_ID=personal-shop-shopware-development
```

Set it before the project's first start. A project that changes its name later starts over with an empty database and a new Claude login; the old ones stay behind under the old name. A `SHOPWARE_DEV_PROJECT_ID` set in the shell wins over the one in `.env`.

## Running several projects at once

Several projects can run side by side, each with its own containers, network and volumes. What they share is this machine's ports: nginx publishes 8000, the database 3306 and Mailpit 8025, and only one project can hold a port at a time. A `php-development` project's nginx counts too, since it publishes 8000 as well. nginx, the database and Mailpit keep running after a session ends, so a project you worked on earlier still holds them, and starting another one fails with `port is already allocated`.

To give a project other ports, copy `.env.example` to `.env` in the same directory:

```sh
cp docker/shopware-development/.env.example docker/shopware-development/.env
```

Then change the ports in `.env`, for example:

```dotenv
SHOPWARE_DEV_HTTP_PORT=8001
SHOPWARE_DEV_DB_PORT=3307
SHOPWARE_DEV_MAIL_PORT=8026
```

That project's shop is then at `http://localhost:8001`, a database GUI connects to `localhost:3307`, and its mails are at `http://localhost:8026`. Inside Docker nothing changes: the shop still reaches the database at `db:3306` and Mailpit at `mailpit:1025`.

Shopware has to know the new web port too. Change `APP_URL` in the shop's `.env.local` to `http://localhost:8001`, and the domain of its sales channel in the Administration, as in [Working on an existing shop](#working-on-an-existing-shop).

This `.env` is not the shop's own `.env` or `.env.local` in the project root; Docker Compose and the scripts read this one, and the shop never sees it. The ports apply from the next session on: when it starts, nginx, the database and Mailpit are recreated with the new ports. The database keeps its data, which lives in its volume.

`.env` stays on this machine: the `.gitignore` in this directory keeps it out of git, because which ports are free depends on what else runs on the machine. `.env.example` is committed with the project.

Set the ports in the file, not as shell variables. The scripts call `sudo docker` when your user can't reach the Docker daemon, and sudo doesn't pass shell variables on.

A port of your own under the `php` service, such as the one in [Web server](#web-server), can be a setting the same way. Write it as `"127.0.0.1:${SHOPWARE_DEV_APP_PORT:-8080}:8080"` in `compose.yml` and put `SHOPWARE_DEV_APP_PORT=8081` in `.env`. Add it to `.env.example` too, with its default, so the next person to copy that file finds it.

## What gets mounted

| Host | Container | Why |
|---|---|---|
| `../..` (the project root containing `docker/`) | `/workspace`, read-only in the `nginx` container | Your code, live |
| `home` (named volume) | `/home/dev` | Claude Code with its login + history, the Composer and npm caches |
| `~/.config/git/config` | `/etc/gitconfig` (read-only) | Your git name, email and settings; added by `start-docker.sh` when the file exists |
| `nginx.conf` | `/etc/nginx/conf.d/default.conf` in the `nginx` container (read-only) | The site nginx serves |
| `php-fpm.conf` | `/etc/php-fpm.conf` in the `fpm` container (read-only) | PHP-FPM's settings |
| `php.ini` | `/etc/php/project.ini` in the `php` and `fpm` containers (read-only) | PHP settings for both |
| `db` (named volume) | `/var/lib/mysql` in the `db` container | The database's data |

## Not included

- **An IDE.** No step debugger or profiler. Xdebug is only set up for coverage; step debugging needs an IDE on the host that listens for it. Everything goes through Composer, `bin/console`, the test runner and Claude.
- **HTTPS.** nginx serves plain HTTP.
- **Docker inside the container.** Tests that start containers themselves cannot run here. Point them at the `db` service instead.
- **Other services.** MySQL and Mailpit are the only ones set up. There is no Redis, OpenSearch or message broker; Shopware runs without them, with its cache in `var/` and its message queue in the database.
- **Git credentials.** Commits made in the container carry your name and email, but there are no SSH keys or tokens inside. Push from the host.

## Caveats

- **localhost is the container itself.** Inside the `php` and `fpm` containers, `http://localhost:8000` doesn't reach nginx, so a request the shop makes to its own `APP_URL` fails. The Administration may warn that `APP_URL` can't be reached, and apps, which call back to the shop, don't work; plugins are not affected. The watchers, `bin/watch-administration.sh` and `bin/watch-storefront.sh`, have the same problem: they run a server of their own in the session's container that forwards to `APP_URL`, and their ports aren't published. Build with `bin/build-js.sh` and reload the page instead.
- **One container per project.** A second `start-docker.sh` joins the running container; its sessions end when the first command exits.
- **One PHP version.** The image has only the PHP set by `PHP_VERSION`, and the session and PHP-FPM share it. A shop that needs a different version needs a rebuild with another value.
- **Composer updates with a rebuild.** `composer self-update` fails, because the image's copy belongs to root. Instead, every `build-docker.sh` checks for a newer 2.x release and takes it, so a build needs a connection to getcomposer.org. Version 3 won't come in on its own: when it is out, change `COMPOSER_VERSION` in the `Dockerfile`. See [PHP, Composer, Node.js and Git updates](#php-composer-nodejs-and-git-updates).
- **MySQL is pinned to version 8.4.** A newer version upgrades the data, and the older one can't open it afterwards. Before changing the version in `compose.yml`, follow [Moving to another MySQL version](#moving-to-another-mysql-version).
- **The `mysql`, `nginx` and `mailpit` images stay on disk** after `remove-docker.sh`, because other projects share them. Remove them by hand with `docker image rm mysql:8.4 nginx:1.30 axllent/mailpit:v1.33` when no project needs them.
- **Host git settings can misfire.** Commit signing, a custom editor or pager and credential helpers rely on programs and keys the container doesn't have. Override them inside with `git config --global`, for example `git config --global commit.gpgsign false`; that is stored in the `home` volume.
- **UID is baked into the image.** Rebuild if your `id -u` changes.
