ARG PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz"
ARG PROTON_INSTALL_DIR="/home/user/.local/share/Steam/compatibilitytools.d/"
ARG PROTON_PATH="${PROTON_INSTALL_DIR}/proton"

FROM quay.io/archlinux/archlinux:multilib-devel AS wine-base

ARG PROTON_PATH
ARG PROTON_INSTALL_DIR
ARG PROTON_URL

RUN pacman-key --init && pacman-key --populate archlinux && pacman -Syu --noconfirm

RUN pacman -S --needed --noconfirm umu-launcher  \
    wget tar \
    {lib32-,}{nvidia-utils,vulkan-{radeon,intel}}
# DEBUG utils
RUN pacman -S --needed --noconfirm mesa-utils vulkan-tools

RUN pacman -Scc

# Create passwordless user and make nvidia libraries discoverable
RUN useradd -m  user

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
 && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

# Configure audio driver
COPY pulse-client.conf /etc/pulse/client.conf

USER user
WORKDIR /home/user

# Required for non-glvnd setups
# ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64

ADD --chown=user:user https://cdn.zwift.com/app/ZwiftSetup.exe ZwiftSetup.exe

ENV PROTONPATH=${PROTON_PATH}

# Proton
RUN mkdir -p ".local/share/Steam/compatibilitytools.d/"

RUN curl -L ${PROTON_URL} | tar -x -z -C ${PROTON_INSTALL_DIR} -f -

# stable proton path
RUN ln -s "$(find ${PROTON_INSTALL_DIR} -mindepth 1 -maxdepth 1 -type d)" "${PROTON_PATH}"

FROM wine-base

ARG PROTON_PATH

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV WINEDEBUG=fixme-all
ENV PROTONPATH=${PROTON_PATH}
ENV GAMEID=umu-zwift

LABEL org.opencontainers.image.authors="Kim Eik <kim@heldig.org>"
LABEL org.opencontainers.image.title="netbrain/zwift"
LABEL org.opencontainers.image.description="Easily zwift on linux"
LABEL org.opencontainers.image.url="https://github.com/netbrain/zwift"

COPY --chmod=755 entrypoint.sh /bin/entrypoint
COPY --chmod=755 update_zwift.sh /bin/update_zwift.sh
COPY --chmod=755 run_zwift.sh /bin/run_zwift.sh
COPY --chmod=755 zwift-auth.sh /bin/zwift-auth
COPY --chown=user:user protonfixes_zwift.py /home/user/.config/protonfixes/localfixes/umu-zwift.py

ENTRYPOINT ["entrypoint"]
