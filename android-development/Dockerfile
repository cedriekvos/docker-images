# JDK that runs Gradle; current Android Gradle Plugin releases need 17 or newer.
ARG JDK_VERSION=21
FROM eclipse-temurin:${JDK_VERSION}-jdk-noble

# Git comes from the Ubuntu Git maintainers' archive (ppa:git-core/ppa),
# because Ubuntu's own package is years behind. --error-on=any stops the
# build when that archive can't be read, instead of quietly installing
# Ubuntu's Git.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl software-properties-common unzip \
 && add-apt-repository -y ppa:git-core/ppa \
 && apt-get update --error-on=any \
 && apt-get install -y --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

# Standalone Gradle, only for bootstrapping a new project (`gradle wrapper`).
# Builds go through the project's own ./gradlew.
ARG GRADLE_VERSION=9.8.0
RUN curl -fsSL -o /tmp/gradle.zip \
        "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
 && unzip -q /tmp/gradle.zip -d /opt \
 && ln -s "/opt/gradle-${GRADLE_VERSION}/bin/gradle" /usr/local/bin/gradle \
 && rm /tmp/gradle.zip

# Non-root user matching host UID/GID (override at build time if yours differ).
# The Ubuntu base image ships an "ubuntu" user that already occupies 1000:1000.
ARG UID=1000
ARG GID=1000
RUN if id ubuntu > /dev/null 2>&1; then userdel --remove ubuntu; fi \
 && groupadd --non-unique --gid ${GID} dev \
 && useradd --non-unique --uid ${UID} --gid ${GID} --create-home --shell /bin/bash dev \
 && install -d -o dev -g dev /opt/android-sdk

USER dev

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

# Android SDK. ANDROID_PLATFORM must match the project's compileSdk and
# ANDROID_BUILD_TOOLS the version its Android Gradle Plugin asks for; anything
# else is downloaded again in every session, because containers are thrown away.
ARG CMDLINE_TOOLS_BUILD=13114758
ARG ANDROID_PLATFORM=36
ARG ANDROID_BUILD_TOOLS=36.0.0
RUN curl -fsSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip" \
 && unzip -q /tmp/cmdline-tools.zip -d /tmp \
 && mkdir "${ANDROID_HOME}/cmdline-tools" \
 && mv /tmp/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest" \
 && rm /tmp/cmdline-tools.zip \
 && yes | sdkmanager --licenses > /dev/null \
 && sdkmanager "platform-tools" "platforms;android-${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}"

# Claude Code, installed in the home directory. Docker copies that into the
# home volume when the volume is first used; from then on Claude Code runs
# from the volume and updates itself there, so a rebuild no longer changes it.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && /home/dev/.local/bin/claude --version

ENV PATH="/home/dev/.local/bin:${PATH}"

WORKDIR /workspace
CMD ["claude"]
