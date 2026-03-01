ARG BUILDPLATFORM

###############################################
FROM --platform=$BUILDPLATFORM debian:13-slim AS downloader
ARG TARGETPLATFORM

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        gnupg

RUN mkdir /dl && \
    wget -O - https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /dl/winehq-archive.key && \
    wget -O /dl/winehq-trixie.sources https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources && \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      wget -O - https://github.com/AndreRH/hangover/releases/download/hangover-11.0/hangover_11.0_debian13_trixie_arm64.tar | tar -C /dl -xv; \
    fi

###############################################
FROM debian:13-slim
LABEL org.opencontainers.image.authors="Davide Depau <davide@depau.eu>"

ARG TARGETPLATFORM

RUN useradd -m -d /home/wineuser -s /bin/bash --uid 1000 wineuser && \
    mkdir /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    # Make sure subsequent Dockerfile RUN statement uses bash \
    mv /bin/sh /bin/sh.old && \
    ln -s /bin/bash /bin/sh

ARG DPKG_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        locales \
        tini \
        wget \
        x11-utils  \
        xvfb \
      && \
    locale-gen en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,from=downloader,source=/dl,target=/mnt \
    set -x && \
    if [[ "$TARGETPLATFORM" == "linux/amd64" ]]; then \
      # Use vanilla Wine on AMD64, with WoW64 \
      mkdir -pm755 /etc/apt/keyrings && \
      cp /mnt/winehq-archive.key /etc/apt/keyrings/ && \
      cp /mnt/winehq-trixie.sources /etc/apt/sources.list.d/ && \
      dpkg --add-architecture i386 &&  \
      apt-get update && \
      apt-get install -y --no-install-recommends winehq-stable; \
    else \
      # Use Hangover with FEX and Box64 on ARM64, with WoW64 \
      apt-get update && \
      apt-get install -y --no-install-recommends /mnt/hangover*.deb; \
    fi && \
    rm -rf /var/lib/apt/lists/*

ENV WINEDEBUG=-all,-fixme,-fixme-all \
    XVFB_SCREEN=0 \
    XVFB_RESOLUTION="320x240x8" \
    DISPLAY=":95" \
    LANG=en_US.UTF-8

COPY scripts/auto_xvfb.sh /usr/local/bin/auto_xvfb
COPY scripts/download_gecko_and_mono.sh /usr/local/bin/download_gecko_and_mono.sh

RUN chmod +x /usr/local/bin/download_gecko_and_mono.sh && \
    download_gecko_and_mono.sh "$(wine --version | sed -E 's/^wine-([0-9]*.[0-9]*).*/\1/')"

RUN wget -nv -O /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/bin/winetricks

USER wineuser
RUN source auto_xvfb && \
    wineboot -i && \
    wineserver -k
