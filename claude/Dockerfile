FROM ubuntu:noble

# Keeps apt from stopping the build with questions, such as tzdata's time zone.
ARG DEBIAN_FRONTEND=noninteractive

# Node.js, for MCP servers that start with npx and for JavaScript tools. 26 is
# the current LTS line. This is the major version; apt installs its newest
# release.
ARG NODE_VERSION=26

# Git comes from the Ubuntu Git maintainers' archive (ppa:git-core/ppa),
# because Ubuntu's own package is years behind. Node.js, with npm, comes from
# NodeSource's archive, because Ubuntu's is version 18. --error-on=any stops
# the build when an archive can't be read, instead of quietly installing
# Ubuntu's Git or Node.js. Python is Ubuntu's own, 3.12, with pip and venv.
# The rest are tools Claude reaches for: ripgrep to search, jq for JSON, zip
# and unzip, file to tell what a file holds, ps and the time zones
# start-docker.sh picks from.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl software-properties-common \
 && add-apt-repository -y ppa:git-core/ppa \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key -o /etc/apt/keyrings/nodesource.asc \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
 && apt-get update --error-on=any \
 && apt-get install -y --no-install-recommends git nodejs \
        python3 python3-pip python3-venv \
        ripgrep jq zip unzip file procps tzdata \
 && rm -rf /var/lib/apt/lists/*

# UTF-8 for every program, instead of the plain C locale's ASCII.
ENV LANG=C.UTF-8

# pandas and matplotlib, for working with data and drawing charts. pip installs
# them as root into the system's Python (/usr/local), so they are part of the
# image instead of the home volume: a new volume, such as after
# remove-docker.sh, has them too. A copy that pip installs later as Claude's
# user goes into ~/.local, and Python loads that one first.
RUN python3 -m pip install --no-cache-dir --break-system-packages --root-user-action=ignore \
        pandas matplotlib \
 && python3 -c "import pandas, matplotlib"

# Non-root user matching host UID/GID (override at build time if yours differ).
# The Ubuntu base image ships an "ubuntu" user that already occupies 1000:1000.
ARG UID=1000
ARG GID=1000
RUN if id ubuntu > /dev/null 2>&1; then userdel --remove ubuntu; fi \
 && groupadd --non-unique --gid ${GID} claude \
 && useradd --non-unique --uid ${UID} --gid ${GID} --create-home --shell /bin/bash claude

USER claude
WORKDIR /home/claude

# Claude Code, installed in the home directory. Docker copies that into the
# home volume when the volume is first used; from then on Claude Code runs
# from the volume and updates itself there, so a rebuild no longer changes it.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && /home/claude/.local/bin/claude --version

# uv runs Python scripts with the packages they name, and Python MCP servers
# through uvx; it downloads another Python when one is asked for. Like Claude
# Code it lives in the home volume and updates itself there (uv self update).
RUN curl -fsSL https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh \
 && /home/claude/.local/bin/uv --version

ENV PATH="/home/claude/.local/bin:${PATH}"

# Packages Claude installs land in the home volume, so they are there in the
# next session too. pip, as a user that can't write to the system's Python,
# installs into ~/.local; the variable only lifts Ubuntu's ban on pip, which
# protects system packages this user can't change anyway. npm installs global
# packages into ~/.local as well, instead of /usr, which needs root.
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV NPM_CONFIG_PREFIX=/home/claude/.local

ENTRYPOINT ["claude"]
