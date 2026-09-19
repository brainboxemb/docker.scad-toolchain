ARG TOOLCHAIN_VERSION=0.6.1
ARG PYTHONSCAD_VERSION=1.1.2
ARG BOSL2_VERSION=2.0.752
ARG PYBOSL2_VERSION=0.6.7
ARG SHAPELY_VERSION=2.1.2
ARG OPENSCAD_DOCSGEN_VERSION=2.0.55
ARG PILLOW_VERSION=12.3.0
ARG SCONS_VERSION=4.11.1
ARG DRAWSVG_VERSION=2.4.2

FROM ubuntu:24.04 AS openscad

ARG DEBIAN_FRONTEND=noninteractive
ARG TOOLCHAIN_VERSION
ARG BOSL2_VERSION
ARG OPENSCAD_DOCSGEN_VERSION
ARG PILLOW_VERSION
ARG SCONS_VERSION

LABEL org.opencontainers.image.title="SCAD toolchain OpenSCAD runtime"
LABEL org.opencontainers.image.description="OpenSCAD + BOSL2 + documentation and build tooling"
LABEL org.opencontainers.image.source="https://github.com/brainboxemb/docker.scad-toolchain"
LABEL org.opencontainers.image.scad-toolchain-profile="openscad"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget jq gnupg git xvfb \
    fontconfig fonts-dejavu-core \
    libgl1 libegl1 libx11-6 libxext6 libxrender1 libxi6 libxkbcommon0 \
    libdbus-1-3 libglib2.0-0 \
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

# BOSL2 is part of the shared OpenSCAD-facing runtime.
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

# Shared OpenSCAD project tooling. Pillow remains here because the public
# scad-image-watermark command is part of normal OpenSCAD publication.
RUN python3 -m pip install \
      --no-cache-dir \
      --break-system-packages \
      "openscad_docsgen==${OPENSCAD_DOCSGEN_VERSION}" \
      "Pillow==${PILLOW_VERSION}" \
      "SCons==${SCONS_VERSION}" \
    && openscad-docsgen --help >/dev/null \
    && openscad-mdimggen --help >/dev/null \
    && scons --version >/dev/null \
    && python3 -c 'from PIL import Image; assert Image'

ENV SCAD_TOOLCHAIN_PROFILE=openscad
ENV SCAD_TOOLCHAIN_VERSION=${TOOLCHAIN_VERSION}
ENV OPENSCADPATH=/opt/openscad-libraries
ENV BOSL2_ROOT=/opt/openscad-libraries/BOSL2
ENV BOSL2_VERSION=${BOSL2_VERSION}
ENV OPENSCAD_DOCSGEN_VERSION=${OPENSCAD_DOCSGEN_VERSION}
ENV PILLOW_VERSION=${PILLOW_VERSION}
ENV SCONS_VERSION=${SCONS_VERSION}
ENV QT_QPA_PLATFORM=offscreen

COPY scripts/scad-toolchain-info /usr/local/bin/scad-toolchain-info
COPY scripts/scad-image-watermark /usr/local/bin/scad-image-watermark
COPY scripts/build-open-source-acknowledgments.py /usr/local/bin/build-open-source-acknowledgments
COPY compliance/OPEN_SOURCE_ACKNOWLEDGMENTS.txt /usr/local/share/scad-toolchain/OPEN_SOURCE_ACKNOWLEDGMENTS.txt
RUN chmod +x \
      /usr/local/bin/scad-toolchain-info \
      /usr/local/bin/scad-image-watermark \
      /usr/local/bin/build-open-source-acknowledgments \
    && build-open-source-acknowledgments \
      --input /usr/local/share/scad-toolchain/OPEN_SOURCE_ACKNOWLEDGMENTS.txt \
      --output-dir /usr/share/doc/scad-toolchain \
      --profile openscad

WORKDIR /work
CMD ["scad-toolchain-info"]


FROM openscad AS drawing

ARG DEBIAN_FRONTEND=noninteractive
ARG TOOLCHAIN_VERSION
ARG DRAWSVG_VERSION

LABEL org.opencontainers.image.title="SCAD toolchain drawing runtime"
LABEL org.opencontainers.image.description="OpenSCAD toolchain plus deterministic technical-drawing publication with Inkscape"
LABEL org.opencontainers.image.scad-toolchain-profile="drawing"

RUN apt-get update && apt-get install -y --no-install-recommends inkscape \
    && rm -rf /var/lib/apt/lists/*

# Python owns readable SVG composition. Inkscape remains the separate
# rendering/export layer, so drawsvg is installed without raster extras.
RUN python3 -m pip install \
      --no-cache-dir \
      --break-system-packages \
      "drawsvg==${DRAWSVG_VERSION}" \
    && python3 -c 'import drawsvg, importlib.metadata as m; assert m.version("drawsvg")'

ENV SCAD_TOOLCHAIN_PROFILE=drawing
ENV DRAWSVG_VERSION=${DRAWSVG_VERSION}

RUN build-open-source-acknowledgments \
      --input /usr/local/share/scad-toolchain/OPEN_SOURCE_ACKNOWLEDGMENTS.txt \
      --output-dir /usr/share/doc/scad-toolchain \
      --profile drawing

CMD ["scad-toolchain-info"]


FROM openscad AS full

ARG DEBIAN_FRONTEND=noninteractive
ARG TOOLCHAIN_VERSION
ARG PYTHONSCAD_VERSION
ARG PYBOSL2_VERSION
ARG SHAPELY_VERSION

LABEL org.opencontainers.image.title="SCAD toolchain full runtime"
LABEL org.opencontainers.image.description="OpenSCAD toolchain plus PythonSCAD and Python CAD interoperability tooling"
LABEL org.opencontainers.image.scad-toolchain-profile="full"

# PythonSCAD currently needs FUSE compatibility libraries at runtime even
# though the AppImage is extracted during the image build.
RUN apt-get update && apt-get install -y --no-install-recommends libfuse2 \
    && rm -rf /var/lib/apt/lists/*

# PythonSCAD release AppImage. Resolve the exact Linux x86_64 AppImage from the
# requested GitHub release so the Dockerfile does not depend on an asset name.
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
    curl -fL \
      "https://raw.githubusercontent.com/pythonscad/pythonscad/v${PYTHONSCAD_VERSION}/COPYING" \
      -o /opt/pythonscad/COPYING.upstream; \
    ln -s /opt/pythonscad/AppRun /usr/local/bin/pythonscad

# Python-only CAD libraries remain confined to the full runtime. They are kept
# under an explicit path because PythonSCAD's embedded runtime may require the
# path to be inserted by consumers.
RUN python3 -m pip install \
      --no-cache-dir \
      --break-system-packages \
      --target /opt/python-libs \
      "pybosl2==${PYBOSL2_VERSION}" \
      "shapely==${SHAPELY_VERSION}" \
    && PYTHONPATH=/opt/python-libs python3 -c \
      'import importlib.metadata as m; import pybosl2; import shapely; assert m.version("pybosl2"); assert m.version("shapely")'

ENV SCAD_TOOLCHAIN_PROFILE=full
ENV PYTHONPATH=/opt/python-libs
ENV PYTHONSCAD_VERSION=${PYTHONSCAD_VERSION}
ENV PYBOSL2_VERSION=${PYBOSL2_VERSION}
ENV SHAPELY_VERSION=${SHAPELY_VERSION}

RUN build-open-source-acknowledgments \
      --input /usr/local/share/scad-toolchain/OPEN_SOURCE_ACKNOWLEDGMENTS.txt \
      --output-dir /usr/share/doc/scad-toolchain \
      --profile full

CMD ["scad-toolchain-info"]
