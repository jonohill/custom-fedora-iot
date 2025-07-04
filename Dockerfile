# syntax=docker/dockerfile:1-labs

ARG IMAGE_BASE=quay.io/fedora/fedora-iot

# This points to the very latest (usually prerelease)
# It's mainly here to cause rebuilds when renovate updates it
ARG IMAGE_TAG=43@sha256:0aa7f4012f704358b12f2f586819a1d6a6e31b195eab2c8130be1c9ca2c03926

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
