# syntax=docker/dockerfile:1-labs

ARG IMAGE_BASE=quay.io/fedora/fedora-iot

# This points to the very latest (usually prerelease)
# It's mainly here to cause rebuilds when renovate updates it
ARG IMAGE_TAG=43@sha256:6c4e7fc4c5a9256997df1182ce142b905811294f3497ccc192e2a7e050c4e0fa

FROM ${IMAGE_BASE}:${IMAGE_TAG}

RUN dnf install -y \
cockpit \
htop \
ncurses \
tailscale

ARG WITH_RPI_KERNEL=true
COPY dwrobel-kernel-rpi.repo /etc/yum.repos.d/
RUN [ "${WITH_RPI_KERNEL}" = "true" ] && \
    dnf install -y grubby && \
    mkdir -p /boot/dtb && \
    dnf remove -y kernel kernel-core kernel-modules-core && \
    dnf install -y --repo="copr:copr.fedorainfracloud.org:dwrobel:kernel-rpi" kernel kernel-core && \
    find /usr/lib/modules -name vmlinux -execdir mv {} vmlinuz \; && \
    rm -rf /boot/*

RUN systemctl --root=/ enable tailscaled && \
    systemctl --root=/ enable cockpit.socket

RUN firewall-offline-cmd --add-service=cockpit

COPY --chown=root:root root/etc /etc

RUN systemctl --root=/ enable rpm-ostreed-automatic.timer

RUN bootc container lint
