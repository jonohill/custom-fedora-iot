# syntax=docker/dockerfile:1-labs

ARG IMAGE_BASE=quay.io/fedora/fedora-iot

# This points to the very latest (usually prerelease)
# It's mainly here to cause rebuilds when renovate updates it
ARG IMAGE_TAG=43@sha256:f847f9bd6f8e7814364b2f0843fa2bcc21347d06075ca3917ff093a013fd5c07

FROM ${IMAGE_BASE}:${IMAGE_TAG}

# dnf needs privileged to succeed, bug?
RUN --security=insecure dnf install -y \
    cockpit \
    ncurses \
    tailscale

RUN systemctl --root=/ enable tailscaled && \
    systemctl --root=/ enable cockpit.socket

RUN firewall-offline-cmd --add-service=cockpit

COPY --chown=root:root root/etc /etc

RUN systemctl --root=/ enable rpm-ostreed-automatic.timer

RUN bootc container lint
