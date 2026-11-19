# docker login
# docker build -t mnbthunder/code-server-opencode:latest .
# docker push mnbthunder/code-server-opencode:latest
# OpenCode clipboard issue tracker: https://github.com/anomalyco/opencode/issues/4283#issuecomment-3771538320

FROM lscr.io/linuxserver/code-server:latest

ARG TARGETARCH

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl ripgrep tar \
  && rm -rf /var/lib/apt/lists/*

# Install OpenCode v2.
# We install into the script's default directory first, then copy the binary into /usr/local/bin
# to preserve the existing PATH behavior in this image.
RUN curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path \
  && install -m 0755 "${HOME}/.opencode/bin/opencode" /usr/local/bin/opencode \
  && rm -rf "${HOME}/.opencode"/cache/* 2>/dev/null || true

RUN opencode --version
