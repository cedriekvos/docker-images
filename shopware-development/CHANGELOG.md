# Changelog

## Version 1

* Initial version, made from `php-development` version 2 for Shopware 6: PHP, Composer, Node.js and Claude Code on an Ubuntu base. nginx with PHP-FPM serves the shop, a MySQL 8.4 database runs next to the container, and Mailpit catches the mails the shop sends.
* The build checks that PHP has every extension Shopware asks for, OPcache included.
* PHP has room for Shopware: 512 MB and five minutes for a web request, OPcache sized for its number of files, and uploads up to 32 MB.
* nginx follows Shopware's own configuration: no PHP in the media, theme and bundle folders, SVGs without scripts, and buffers that take the Symfony profiler's long headers.
