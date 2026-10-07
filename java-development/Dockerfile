# JDK that builds and runs the project.
ARG JDK_VERSION=25
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

# Maven and Gradle, for projects without a wrapper and for creating one.
# A project that has its own ./mvnw or ./gradlew should be built with that.
ARG MAVEN_VERSION=3.10.0
RUN curl -fsSL -o /tmp/maven.tar.gz \
        "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
 && tar -xzf /tmp/maven.tar.gz -C /opt \
 && ln -s "/opt/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn \
 && rm /tmp/maven.tar.gz

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
