FROM quay.io/archlinux/archlinux:multilib-devel AS wine-base

RUN pacman-key --init && pacman-key --populate archlinux && pacman -Syu --noconfirm

RUN pacman -S --needed --noconfirm umu-launcher wget vulkan-{radeon,intel} nvidia-utils tar xz

RUN pacman -S --needed --noconfirm mesa-utils vulkan-tools

RUN pacman -Scc

# Create passwordless user and make nvidia libraries discoverable
RUN useradd -m  user \
 && echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
 && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

# Required for non-glvnd setups
# ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64

ADD --chown=user:user https://cdn.zwift.com/app/ZwiftSetup.exe /home/user/ZwiftSetup.exe
ADD --chown=user:user https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-34/GE-Proton10-34.tar.gz /tmp/proton.tar.xz

RUN mkdir -p "/home/user/.local/share/Steam/compatibilitytools.d/"
RUN tar -xf /tmp/proton.tar.xz -C "/home/user/.local/share/Steam/compatibilitytools.d/"

RUN chown user:user -R "/home/user/"


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
COPY --chown=user:user protonfixes_zwift.py /home/user/.config/protonfixes/localfixes/umu-zwift.py

ENTRYPOINT ["entrypoint"]

USER user
