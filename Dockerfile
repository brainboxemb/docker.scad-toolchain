FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHONSCAD_VERSION=1.1.2
ARG BOSL2_VERSION=2.0.752
ARG PYBOSL2_VERSION=0.6.7

LABEL org.opencontainers.image.title="SCAD toolchain"
LABEL org.opencontainers.image.description="OpenSCAD + PythonSCAD + BOSL2 + pybosl2 CI toolchain"
LABEL org.opencontainers.image.source="https://github.com/brainboxemb/docker.scad-toolchain"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget jq gnupg git xvfb \
    fontconfig fonts-dejavu-core \
    libgl1 libegl1 libx11-6 libxext6 libxrender1 libxi6 libxkbcommon0 \
    libdbus-1-3 libglib2.0-0 libfuse2 \
    python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# OpenSCAD development snapshot from the official OBS repository.
RUN wget -qO /etc/apt/trusted.gpg.d/obs-openscad-nightly.asc \
      https://files.openscad.org/OBS-Repository-Key.pub \
    && echo 'deb https://download.opensuse.org/repositories/home:/t-paul/xUbuntu_24.04/ /' \
      > /etc/apt/sources.list.d/openscad-nightly.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends openscad-nightly \
    && ln -s "$(command -v openscad-nightly)" /usr/local/bin/openscad \
    && rm -rf /var/lib/apt/lists/*

# PythonSCAD release AppImage. Resolve the exact Linux x86_64 AppImage from the
# requested GitHub release so the Dockerfile does not depend on an asset filename.
RUN set -eux; \
    release="$(curl -fsSL "https://api.github.com/repos/pythonscad/pythonscad/releases/tags/v${PYTHONSCAD_VERSION}")"; \
    url="$(printf '%s' "$release" | jq -r '[.assets[] | select(.name | test("(?i)(x86_64|amd64).*\\.AppImage$|\\.AppImage.*(x86_64|amd64)$"))][0].browser_download_url // empty')"; \
    if [ -z "$url" ]; then \
      url="$(printf '%s' "$release" | jq -r '[.assets[] | select(.name | endswith(".AppImage"))][0].browser_download_url // empty')"; \
    fi; \
    test -n "$url"; \
    curl -fL "$url" -o /tmp/pythonscad.AppImage; \
    chmod +x /tmp/pythonscad.AppImage; \
    cd /opt; \
    /tmp/pythonscad.AppImage --appimage-extract >/dev/null; \
    mv squashfs-root pythonscad; \
    rm /tmp/pythonscad.AppImage; \
    ln -s /opt/pythonscad/AppRun /usr/local/bin/pythonscad

# BOSL2 is installed as a normal OpenSCAD library under a stable path.
# OPENSCADPATH below makes <BOSL2/...> includes work in consuming projects.
RUN set -eux; \
    mkdir -p /opt/openscad-libraries /tmp/bosl2; \
    curl -fL \
      "https://github.com/BelfrySCAD/BOSL2/archive/refs/tags/v${BOSL2_VERSION}.tar.gz" \
      -o /tmp/bosl2.tar.gz; \
    tar -xzf /tmp/bosl2.tar.gz -C /tmp/bosl2; \
    src="$(find /tmp/bosl2 -mindepth 1 -maxdepth 1 -type d | head -n1)"; \
    test -n "$src"; \
    mv "$src" /opt/openscad-libraries/BOSL2; \
    rm -rf /tmp/bosl2 /tmp/bosl2.tar.gz; \
    test -f /opt/openscad-libraries/BOSL2/std.scad

# Install the Python BOSL2 port into an explicit shared library directory.
# PYTHONPATH makes the package available to both system Python and, when the
# embedded runtime honours PYTHONPATH, PythonSCAD. The external consumer test
# deliberately verifies the PythonSCAD case.
RUN python3 -m pip install \
      --no-cache-dir \
      --break-system-packages \
      --target /opt/python-libs \
      "pybosl2==${PYBOSL2_VERSION}" \
    && PYTHONPATH=/opt/python-libs python3 -c \
      'import importlib.metadata as m; assert m.version("pybosl2")'

ENV OPENSCADPATH=/opt/openscad-libraries
ENV PYTHONPATH=/opt/python-libs
ENV BOSL2_VERSION=${BOSL2_VERSION}
ENV PYBOSL2_VERSION=${PYBOSL2_VERSION}
ENV QT_QPA_PLATFORM=offscreen

COPY scripts/scad-toolchain-info /usr/local/bin/scad-toolchain-info
RUN chmod +x /usr/local/bin/scad-toolchain-info

WORKDIR /work

CMD ["scad-toolchain-info"]
