ARG DEBIAN_VERSION=trixie

FROM rust:1.95.0-slim-trixie AS build-runfromprocess

ARG RUNFROMPROCESS_VERSION=a3d003c07d1bd11ff93c4cac96d2c3aa5deb8471

# Install prerequisites
# - mingw to cross-compile for windows
# - rust cross-compiler for windows
RUN DEBIAN_FRONTEND="noninteractive" apt-get update \
 && DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y g++-mingw-w64-x86-64 \
 && rm -rf /var/lib/apt/lists/* \
 && rustup target add x86_64-pc-windows-gnu

# Build runfromprocess
WORKDIR /usr/src
ADD https://github.com/quietvoid/runfromprocess-rs.git#${RUNFROMPROCESS_VERSION} .
RUN cargo build --target x86_64-pc-windows-gnu --release

FROM debian:${DEBIAN_VERSION}-slim AS wine-base

# Wine
# - 11.0     : support 32-bit applications through wow64
# - 10.17    : default to egl for opengl in x11
# - 9.9      : support native wayland
# Winetricks
# - 20260125 : webview2 in zwift launcher works
# - 20240105 : first version used in this Dockerfile
ARG DEBIAN_VERSION
ARG WINE_BRANCH="devel"
ARG WINE_VERSION="=11.5~${DEBIAN_VERSION}-1"
ARG WINETRICKS_VERSION=20260125
ARG WINETRICKS_CHECKSUM=431f82fc74000e6c864409f1d8fb495d696c03928808e3e8acffc45179312a7b

# Install prerequisites
# - ca-certificates for wget and curl
# - cabextract for winetricks
# - curl used in zwift authentication script
# - gamemode for freedesktop screensaver inhibit
# - gosu for invoking scripts in entrypoint
# - gpg for dearmoring winehq key
# - libegl1 and libgl1 for GL library
# - libvulkan1 for vulkan loader library
# - mesa-utils for testing graphics: glxgears, eglgears_wayland, eglgears_x11
# - procps for pgrep
# - wget for downloading winehq key
# - winbind for ntml_auth required by zwift/wine
# - xdg-utils seems to be a dependency of wayland
RUN dpkg --add-architecture i386 \
 && DEBIAN_FRONTEND="noninteractive" apt-get update \
 && DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends -y \
        ca-certificates \
        cabextract \
        curl \
        gamemode \
        gosu \
        gpg \
        libegl1 \
        libgl1 \
        libgamemode0.i386 \
        libgamemodeauto0.i386 \
        libvulkan1 \
        mesa-utils \
        procps \
        wget \
        winbind \
        xdg-utils \
 && rm -rf /var/lib/apt/lists/*

# Install wine (including recommends, see https://gitlab.winehq.org/wine/wine/-/wikis/Debian-Ubuntu)
# hadolint ignore=DL3015
RUN mkdir -p /etc/apt/keyrings \
 && wget -qO /tmp/winehq.key https://dl.winehq.org/wine-builds/winehq.key \
 && gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key /tmp/winehq.key \
 && rm -f /tmp/winehq.key \
 && wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/${DEBIAN_VERSION}/winehq-${DEBIAN_VERSION}.sources \
 && DEBIAN_FRONTEND="noninteractive" apt-get update \
 && DEBIAN_FRONTEND="noninteractive" apt-get install --install-recommends -y winehq-${WINE_BRANCH}${WINE_VERSION} \
 && rm -rf /var/lib/apt/lists/*

# Download winetricks
ADD --checksum=sha256:${WINETRICKS_CHECKSUM} --chmod=755 https://raw.githubusercontent.com/Winetricks/winetricks/${WINETRICKS_VERSION}/src/winetricks /usr/local/bin/

# Create passwordless user and make nvidia libraries discoverable
RUN adduser --disabled-password --gecos '' user \
 && echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
 && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

# Required for non-glvnd setups
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64

# Configure audio driver
COPY pulse-client.conf /etc/pulse/client.conf

FROM wine-base

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV WINEDEBUG=fixme-all

LABEL org.opencontainers.image.authors="Kim Eik <kim@heldig.org>"
LABEL org.opencontainers.image.title="netbrain/zwift"
LABEL org.opencontainers.image.description="Easily zwift on linux"
LABEL org.opencontainers.image.url="https://github.com/netbrain/zwift"

COPY --chmod=755 entrypoint.sh /bin/entrypoint
COPY --chmod=755 update_zwift.sh /bin/update_zwift.sh
COPY --chmod=755 run_zwift.sh /bin/run_zwift.sh
COPY --chmod=755 zwift-auth.sh /bin/zwift-auth
COPY --from=build-runfromprocess /usr/src/target/x86_64-pc-windows-gnu/release/runfromprocess-rs.exe /bin/runfromprocess-rs.exe

ENTRYPOINT ["entrypoint"]
