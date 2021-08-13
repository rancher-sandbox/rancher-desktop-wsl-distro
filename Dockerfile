FROM alpine as builder

ARG BUILD_ID=
ARG VERSION_ID=0.2

ADD build.sh /
ADD os-release /
RUN /bin/sh /build.sh
ADD kubeconfig /distro/usr/local/bin/
ADD run-k3s /distro/usr/local/bin/
RUN chmod a+x /distro/usr/local/bin/*

FROM scratch
COPY --from=builder /distro/ /
