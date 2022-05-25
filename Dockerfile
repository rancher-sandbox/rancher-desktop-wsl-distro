FROM alpine as builder

ARG BUILD_ID=
ARG VERSION_ID=0.4
ARG NERDCTL_VERSION
ARG AGENT_VERSION
ARG CRI_DOCKERD_VERSION

ADD files/ /
COPY nerdctl-${NERDCTL_VERSION}.tgz /nerdctl.tgz
COPY rancher-desktop-guestagent-${AGENT_VERSION} /rancher-desktop-guestagent
COPY cri-dockerd-${CRI_DOCKERD_VERSION}.tgz /cri-dockerd.tgz
COPY cri-dockerd-${CRI_DOCKERD_VERSION}.LICENSE /cri-dockerd.LICENSE
RUN /bin/sh /build.sh

FROM scratch
COPY --from=builder /distro/ /
