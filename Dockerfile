# syntax=docker/dockerfile:1-labs

ARG IMAGE_BASE=quay.io/fedora/fedora-iot

# This points to the very latest (usually prerelease)
# It's mainly here to cause rebuilds when renovate updates it
ARG IMAGE_TAG=44@sha256:438f2c8d138964ebde052fc4fb55743d29385f5d68096f77f030d719039673e0

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
