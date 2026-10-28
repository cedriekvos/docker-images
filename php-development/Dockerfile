FROM ubuntu:noble

# Keeps apt from stopping the build with questions, such as tzdata's time zone.
ARG DEBIAN_FRONTEND=noninteractive

# PHP that runs the project. Ubuntu's own archive stops at 8.3.
ARG PHP_VERSION=8.5

# Git comes from the Ubuntu Git maintainers' archive (ppa:git-core/ppa),
# because Ubuntu's own package is years behind. PHP and its extensions come
# from Ondřej Surý's archive (ppa:ondrej/php), which has every supported PHP
# release. --error-on=any stops the build when either archive can't be read,
# instead of quietly installing Ubuntu's Git. Composer extracts packages with
# unzip.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl software-properties-common unzip \
 && add-apt-repository -y ppa:git-core/ppa \
 && add-apt-repository -y ppa:ondrej/php \
 && apt-get update --error-on=any \
 && apt-get install -y --no-install-recommends git \
        "php${PHP_VERSION}-cli" \
        "php${PHP_VERSION}-fpm" \
        "php${PHP_VERSION}-bcmath" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-imagick" \
        "php${PHP_VERSION}-intl" \
        "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-pcov" \
        "php${PHP_VERSION}-pgsql" \
        "php${PHP_VERSION}-readline" \
        "php${PHP_VERSION}-sqlite3" \
        "php${PHP_VERSION}-xdebug" \
        "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-zip" \
 && rm -rf /var/lib/apt/lists/*

# The project's php.ini, which compose.yml mounts at /etc/php/project.ini.
# PHP and PHP-FPM read it after the image's own settings, so it wins.
RUN for sapi in cli fpm; do \
      ln -s /etc/php/project.ini "/etc/php/${PHP_VERSION}/${sapi}/conf.d/99-project.ini"; \
    done

# PHP-FPM under a name that doesn't change with PHP_VERSION, for compose.yml.
RUN ln -s "/usr/sbin/php-fpm${PHP_VERSION}" /usr/local/sbin/php-fpm

# Composer. It belongs to root, so `composer self-update` can't replace it;
# a rebuild with another COMPOSER_VERSION does.
ARG COMPOSER_VERSION=2.10.3
RUN curl -fsSL -o /usr/local/bin/composer \
        "https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar" \
 && chmod 755 /usr/local/bin/composer

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
