ARG DEBIAN_VERSION=trixie

FROM rust:1.90-slim AS build-runfromprocess

# Install prerequisites
# - mingw to cross-compile for windows
# - git to fetch runfromprocess source code
# - rust cross-compiler for windows
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
        g++-mingw-w64-x86-64 \
        git \
 && rm -rf /var/lib/apt/lists/* \
 && rustup target add x86_64-pc-windows-gnu

# Build runfromprocess
WORKDIR /usr/src
RUN git clone https://github.com/quietvoid/runfromprocess-rs . \
 && cargo build --target x86_64-pc-windows-gnu --release

FROM debian:${DEBIAN_VERSION}-slim AS build-libstrangle

# Install prerequisites
# - ca-certificates and git to fetch libstrangle source code
# - build-essential for gcc compiler and make
# - g++-multilib, gcc-multilib, libx11-dev, mesa-common-dev required by libstrangle
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
        build-essential \
        ca-certificates \
        g++-multilib \
        gcc-multilib \
        git \
        libx11-dev \
        mesa-common-dev \
 && rm -rf /var/lib/apt/lists/*

# Build libstrangle
# Apply patch to specific commit to fix compilation errors
WORKDIR /usr/libstrangle
COPY libstrangle.patch /usr/libstrangle.patch
RUN git clone https://gitlab.com/torkel104/libstrangle.git . \
 && git checkout 0273e318e3b0cc759155db8729ad74266b74cb9b \
 && git apply /usr/libstrangle.patch \
 && make

FROM debian:${DEBIAN_VERSION}-slim AS wine-base

# As at May 2024 Wayland Native works wine 9.9 or later:
#    WINE_BRANCH="devel"
# For Specific version fix add WINE_VERSION,
# make sure to add "=" to the start, comment out for latest
#    WINE_VERSION="=9.9~bookworm-1"
ARG DEBIAN_VERSION
ARG WINE_BRANCH="devel"
ARG WINE_VERSION="=9.9~${DEBIAN_VERSION}-1"
ARG WINETRICKS_VERSION=20240105

# Install prerequisites
# - ca-certificates for wget and curl
# - curl used in zwift authentication script
# - gamemode for freedesktop screensaver inhibit
# - gosu for invoking scripts in entrypoint
# - libegl1 and libgl1 for GL library
# - libvulkan1 for vulkan loader library
# - procps for pgrep
# - sudo for normal user installation
# - wget for downloading winehq key
# - winbind for ntml_auth required by zwift/wine
# - xdg-utils seems to be a dependency of wayland
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        gamemode \
        gosu \
        libegl1 \
        libgl1 \
        libvulkan1 \
        procps \
        sudo \
        wget \
        winbind \
        xdg-utils \
 && rm -rf /var/lib/apt/lists/*

# Install wine and winetricks (including recommends, which appear to be required)
# hadolint ignore=DL3015
RUN wget -qO /etc/apt/trusted.gpg.d/winehq.asc https://dl.winehq.org/wine-builds/winehq.key \
 && echo "deb https://dl.winehq.org/wine-builds/debian/ ${DEBIAN_VERSION} main" > /etc/apt/sources.list.d/winehq.list \
 && apt-get update \
 && apt-get install -y \
        wine-${WINE_BRANCH}${WINE_VERSION} \
        wine-${WINE_BRANCH}-amd64${WINE_VERSION} \
        wine-${WINE_BRANCH}-i386${WINE_VERSION} \
        winehq-${WINE_BRANCH}${WINE_VERSION} \
 && rm -rf /var/lib/apt/lists/* \
 && wget -qO /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/${WINETRICKS_VERSION}/src/winetricks \
 && chmod +x /usr/local/bin/winetricks

# Create passwordless user and make nvidia libraries discoverable
RUN adduser --disabled-password --gecos '' user \
 && adduser user sudo \
 && echo '%SUDO ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
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
COPY --chmod=755 --from=build-runfromprocess /usr/src/target/x86_64-pc-windows-gnu/release/runfromprocess-rs.exe /bin/runfromprocess-rs.exe
COPY --chmod=644 --from=build-libstrangle /usr/libstrangle/build/libstrangle.conf /etc/ld.so.conf.d/libstrangle.conf
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/build/libstrangle32.so /usr/local/lib/libstrangle/lib32/libstrangle.so
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/build/libstrangle64.so /usr/local/lib/libstrangle/lib64/libstrangle.so
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/build/libstrangle32_nodlsym.so /usr/local/lib/libstrangle/lib32/libstrangle_nodlsym.so
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/build/libstrangle64_nodlsym.so /usr/local/lib/libstrangle/lib64/libstrangle_nodlsym.so
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/build/libstrangle_vk32.so /usr/local/lib/libstrangle/lib32/libstrangle_vk.so
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/build/libstrangle_vk64.so /usr/local/lib/libstrangle/lib64/libstrangle_vk.so
COPY --chmod=644 --from=build-libstrangle /usr/libstrangle/src/vulkan/libstrangle_vk.json /usr/local/share/vulkan/implicit_layer.d/libstrangle_vk.json
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/src/strangle.sh /usr/local/bin/strangle
COPY --chmod=755 --from=build-libstrangle /usr/libstrangle/src/stranglevk.sh /usr/local/bin/stranglevk

# Configure libstrangle shared libraries
RUN ldconfig

ENTRYPOINT ["entrypoint"]
