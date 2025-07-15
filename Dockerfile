# syntax=docker/dockerfile:1-labs

ARG IMAGE_BASE=quay.io/fedora/fedora-iot

# This points to the very latest (usually prerelease)
# It's mainly here to cause rebuilds when renovate updates it
ARG IMAGE_TAG=43@sha256:069a95d4dfa4822fc9e9571370f262692a296bdd8ca626176949b1309f86042c

FROM ${IMAGE_BASE}:${IMAGE_TAG}

RUN dnf install -y \
cockpit \
htop \
ncurses \
tailscale

ARG WITH_RPI_KERNEL=true
ARG TARGETPLATFORM
COPY dwrobel-kernel-rpi.repo /etc/yum.repos.d/
RUN if [ "${WITH_RPI_KERNEL}" = "true" ] && [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        echo "Installing RPi kernel for arm64 platform" && \
        dnf install -y grubby && \
        mkdir -p /boot/dtb && \
        dnf remove -y kernel kernel-core kernel-modules-core && \
        dnf install -y --repo="copr:copr.fedorainfracloud.org:dwrobel:kernel-rpi" kernel kernel-core && \
        find /usr/lib/modules -name vmlinux -execdir mv {} vmlinuz \; && \
        rm -rf /boot/*; \
    else \
        echo "Skipping RPi kernel installation (WITH_RPI_KERNEL=${WITH_RPI_KERNEL}, TARGETPLATFORM=${TARGETPLATFORM})" && \
        rm -f /etc/yum.repos.d/dwrobel-kernel-rpi.repo; \
    fi

RUN systemctl --root=/ enable tailscaled && \
    systemctl --root=/ enable cockpit.socket

RUN firewall-offline-cmd --add-service=cockpit

COPY --chown=root:root root/etc /etc

RUN systemctl --root=/ enable rpm-ostreed-automatic.timer

RUN bootc container lint
