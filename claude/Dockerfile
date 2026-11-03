FROM alpine:3.21

# Native installer needs these on musl
RUN apk add --no-cache libgcc libstdc++ ripgrep curl bash git

# Non-root user matching host UID/GID (override at build time if yours differ)
ARG UID=1000
ARG GID=1000
RUN addgroup -g ${GID} claude \
 && adduser -D -u ${UID} -G claude claude \
 && mkdir -p /claude-home \
 && chown claude:claude /claude-home

USER claude
WORKDIR /home/claude

# Install Claude Code as the non-root user (lands in ~/.local/bin)
RUN curl -fsSL https://claude.ai/install.sh | bash

ENV PATH="/home/claude/.local/bin:${PATH}"
ENV USE_BUILTIN_RIPGREP=0

ENTRYPOINT ["claude"]
