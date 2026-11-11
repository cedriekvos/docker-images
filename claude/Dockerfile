FROM alpine:3.24

# Native installer needs these on musl
RUN apk add --no-cache libgcc libstdc++ ripgrep curl bash git

# Non-root user matching host UID/GID (override at build time if yours differ)
ARG UID=1000
ARG GID=1000
RUN addgroup -g ${GID} claude \
 && adduser -D -u ${UID} -G claude claude

USER claude
WORKDIR /home/claude

# Claude Code, installed in the home directory. Docker copies that into the
# home volume when the volume is first used; from then on Claude Code runs
# from the volume and updates itself there, so a rebuild no longer changes it.
RUN curl -fsSL https://claude.ai/install.sh | bash \
 && /home/claude/.local/bin/claude --version

ENV PATH="/home/claude/.local/bin:${PATH}"
ENV USE_BUILTIN_RIPGREP=0

ENTRYPOINT ["claude"]
