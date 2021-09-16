FROM alpine as builder

ARG BUILD_ID=
ARG VERSION_ID=0.2
ARG NERDCTL_VERSION

ADD build.sh /
ADD os-release /
COPY nerdctl-${NERDCTL_VERSION}.tgz /nerdctl.tgz
RUN /bin/sh /build.sh

FROM scratch
COPY --from=builder /distro/ /
