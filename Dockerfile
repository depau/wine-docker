###############################################
FROM fedora:43
LABEL org.opencontainers.image.authors="Davide Depau <davide@depau.eu>"

ARG TARGETPLATFORM

RUN useradd -m -d /home/wineuser -s /bin/bash --uid 1000 wineuser && \
    mkdir /tmp/.X11-unix && \
    chmod 1777 /tmp/.X11-unix && \
    # Make sure subsequent Dockerfile RUN statement uses bash \
    mv /bin/sh /bin/sh.old && \
    ln -s /bin/bash /bin/sh

RUN dnf -y install \
        bash \
        ca-certificates \
        tini \
        wget \
        xdpyinfo \
        xorg-x11-server-Xvfb \
      && \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      dnf -y copr enable lacamar/wine-arm64ec && \
      dnf -y install fex-emu-wine wine; \
    else \
      dnf -y install wine; \
    fi && \
    rm -f /tmp/.X*lock

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

