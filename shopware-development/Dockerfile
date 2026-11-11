FROM ubuntu:noble

# Keeps apt from stopping the build with questions, such as tzdata's time zone.
ARG DEBIAN_FRONTEND=noninteractive

# PHP that runs the shop. Shopware 6.7.12 and later are tested with 8.5; the
# README says which PHP an older shop needs. Ubuntu's own archive stops at 8.3.
ARG PHP_VERSION=8.5

# Node.js, which builds the JavaScript of the Administration, the Storefront
# and extensions. Shopware 6.7 asks for 20 or newer. This is the major
# version; apt installs its newest release.
ARG NODE_VERSION=22

# Git comes from the Ubuntu Git maintainers' archive (ppa:git-core/ppa),
# because Ubuntu's own package is years behind. PHP and its extensions come
# from Ondřej Surý's archive (ppa:ondrej/php), which has every supported PHP
# release. Node.js, with npm, comes from NodeSource's archive, because
# Ubuntu's is version 18. --error-on=any stops the build when an archive can't
# be read, instead of quietly installing Ubuntu's Git or Node.js. Composer
# extracts packages with unzip. Shopware's build scripts use jq to find the
# extensions whose JavaScript needs npm packages of its own. OPcache is part
# of PHP itself from 8.5 on; an older PHP has it as a package of its own.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl software-properties-common unzip \
 && add-apt-repository -y ppa:git-core/ppa \
 && add-apt-repository -y ppa:ondrej/php \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /etc/apt/keyrings/nodesource.asc \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
 && apt-get update --error-on=any \
 && opcache="" \
 && if dpkg --compare-versions "${PHP_VERSION}" lt 8.5; then opcache="php${PHP_VERSION}-opcache"; fi \
 && apt-get install -y --no-install-recommends git jq nodejs \
        "php${PHP_VERSION}-cli" \
        "php${PHP_VERSION}-fpm" \
        "php${PHP_VERSION}-bcmath" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-intl" \
        "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-pcov" \
        "php${PHP_VERSION}-readline" \
        "php${PHP_VERSION}-xdebug" \
        "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-zip" \
        ${opcache} \
 && rm -rf /var/lib/apt/lists/*

# The PHP extensions Shopware asks for, checked here: a missing one stops the
# build with its name, rather than a later `composer install`.
RUN php -r 'foreach (array_slice($argv, 1) as $name) { if (!extension_loaded($name)) { fwrite(STDERR, "Shopware needs the PHP extension $name\n"); $missing = true; } } exit(isset($missing) ? 1 : 0);' \
      ctype curl dom fileinfo gd iconv intl json libxml mbstring openssl pcre pdo pdo_mysql \
      phar simplexml sodium xml zip zlib "Zend OPcache"

# The project's php.ini, which compose.yml mounts at /etc/php/project.ini.
# PHP and PHP-FPM read it after the image's own settings, so it wins.
RUN for sapi in cli fpm; do \
      ln -s /etc/php/project.ini "/etc/php/${PHP_VERSION}/${sapi}/conf.d/99-project.ini"; \
    done

# PHP-FPM under a name that doesn't change with PHP_VERSION, for compose.yml.
RUN ln -s "/usr/sbin/php-fpm${PHP_VERSION}" /usr/local/sbin/php-fpm

# Composer: latest-2.x is the newest 2.x release; an exact version such as
# 2.10.3 pins it. ADD checks the download on every build, so a plain rebuild
# takes a newer release, where a RUN with curl would stay cached. It belongs to
# root, so `composer self-update` can't replace it.
ARG COMPOSER_VERSION=latest-2.x
ADD --chmod=755 https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar /usr/local/bin/composer

# Non-root user matching host UID/GID (override at build time if yours differ).
# The Ubuntu base image ships an "ubuntu" user that already occupies 1000:1000.
ARG UID=1000
ARG GID=1000
RUN if id ubuntu > /dev/null 2>&1; then userdel --remove ubuntu; fi \
 && groupadd --non-unique --gid ${GID} dev \
 && useradd --non-unique --uid ${UID} --gid ${GID} --create-home --shell /bin/bash dev

USER dev

# Claude Code, installed in the home directory. Docker copies that into the
# home volume when the volume is first used; from then on Claude Code runs
# from the volume and updates itself there, so a rebuild no longer changes it.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && /home/dev/.local/bin/claude --version

ENV PATH="/home/dev/.local/bin:${PATH}"

WORKDIR /workspace
CMD ["claude"]
