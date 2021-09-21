FROM alpine as builder

ARG BUILD_ID=
ARG VERSION_ID=0.4
ARG NERDCTL_VERSION
ARG AGENT_VERSION

ADD build.sh /
ADD os-release /
COPY nerdctl-${NERDCTL_VERSION}.tgz /nerdctl.tgz
COPY rancher-desktop-guestagent-${AGENT_VERSION} /rancher-desktop-guestagent
RUN /bin/sh /build.sh

FROM scratch
COPY --from=builder /distro/ /
