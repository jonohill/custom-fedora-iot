# syntax=docker/dockerfile:1-labs

ARG IMAGE_BASE=quay.io/fedora/fedora-iot

# This points to the very latest (usually prerelease)
# It's mainly here to cause rebuilds when renovate updates it
ARG IMAGE_TAG=43@sha256:ec6e19a6dd1cae79fbc12758abbdbb765410dad19dd387886e0ecf077abd280c

FROM ${IMAGE_BASE}:${IMAGE_TAG}

# dnf needs privileged to succeed, bug?
RUN --security=insecure dnf install -y \
    cockpit \
    htop \
    ncurses \
    tailscale

RUN systemctl --root=/ enable tailscaled && \
    systemctl --root=/ enable cockpit.socket

RUN firewall-offline-cmd --add-service=cockpit

COPY --chown=root:root root/etc /etc

RUN systemctl --root=/ enable rpm-ostreed-automatic.timer

RUN bootc container lint
