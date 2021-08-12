FROM alpine as builder

ADD build.sh /
RUN /bin/sh /build.sh
ADD kubeconfig /distro/usr/local/bin/
ADD run-k3s /distro/usr/local/bin/
RUN chmod a+x /distro/usr/local/bin/*

FROM scratch
COPY --from=builder /distro/ /
