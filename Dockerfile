ARG ALPINE_VERSION=3.19
FROM alpine:${ALPINE_VERSION} as builder

ARG BUILD_ID=
ARG VERSION_ID=0.4
ARG RD_NETWORKING_VERSION
ARG NERDCTL_VERSION
ARG AGENT_VERSION
ARG CRI_DOCKERD_VERSION
ARG OPENRESTY_VERSION

ADD files/ /
COPY rd-networking-${RD_NETWORKING_VERSION}.tgz /rd-networking.tgz
COPY nerdctl-${NERDCTL_VERSION}.tgz /nerdctl.tgz
COPY cri-dockerd-${CRI_DOCKERD_VERSION}.tgz /cri-dockerd.tgz
COPY cri-dockerd-${CRI_DOCKERD_VERSION}.LICENSE /cri-dockerd.LICENSE
ADD openresty-${OPENRESTY_VERSION}-x86_64.tar /openresty
RUN /bin/sh /build.sh

FROM scratch
COPY --from=builder /distro/ /
