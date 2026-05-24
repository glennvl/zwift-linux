FROM archlinux:multilib-devel AS wine-base

RUN pacman -Sy

RUN pacman -S --noconfirm umu-launcher wget vulkan-radeon lib32-vulkan-radeon nvidia-utils lib32-nvidia-utils vulkan-intel lib32-vulkan-intel tar xz

# Create passwordless user and make nvidia libraries discoverable
RUN useradd -m  user \
 && echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf \
 && echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

# Required for non-glvnd setups
# ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64

ADD --chown=user:user https://cdn.zwift.com/app/ZwiftSetup.exe /home/user/ZwiftSetup.exe
ADD --chown=user:user https://github.com/CachyOS/proton-cachyos/releases/download/cachyos-11.0-20260506-slr/proton-cachyos-11.0-20260506-slr-x86_64.tar.xz /tmp/proton.tar.xz

RUN mkdir -p "/home/user/.local/share/Steam/compatibilitytools.d/"
RUN tar -xJvf /tmp/proton.tar.xz -C "/home/user/.local/share/Steam/compatibilitytools.d/"

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
