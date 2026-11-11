# Changelog

## Version 2

* A new shop gets no Docker files from Symfony Flex: the README's install steps run `composer create-project` with `SYMFONY_DOCKER=0`. Without a terminal, as when Claude runs Composer, Flex added a `compose.yaml` and a `compose.override.yaml` to the project root without asking. Flex stores the answer in `composer.json`, so packages added later don't bring Docker files either.

## Version 1

* Initial version, made from `php-development` version 2 for Shopware 6: PHP, Composer, Node.js and Claude Code on an Ubuntu base. nginx with PHP-FPM serves the shop, a MySQL 8.4 database runs next to the container, and Mailpit catches the mails the shop sends.
* The build checks that PHP has every extension Shopware asks for, OPcache included.
* PHP has room for Shopware: 512 MB and five minutes for a web request, OPcache sized for its number of files, and uploads up to 32 MB.
* nginx follows Shopware's own configuration: no PHP in the media, theme and bundle folders, SVGs without scripts, and buffers that take the Symfony profiler's long headers.
