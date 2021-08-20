FROM alpine as builder

ARG BUILD_ID=
ARG VERSION_ID=0.2

ADD build.sh /
ADD os-release /
RUN /bin/sh /build.sh

FROM scratch
COPY --from=builder /distro/ /
