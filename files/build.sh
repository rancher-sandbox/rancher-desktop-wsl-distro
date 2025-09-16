#!/bin/sh

# This is a shell script that generates the target files in a temporary root folder /distro

# shellcheck shell=ash

set -o errexit -o nounset -o xtrace

# Bootstrap an alpine chroot in /distro
apk add -U alpine-conf
mkdir /distro
lbu package - | tar -C /distro -zx
# Remove unnecessary packages
rm -f /distro/etc/apk/world
apk --root /distro --update-cache add --initdb busybox

# Add openrc
apk --root /distro add openrc
cat rc.conf >> /distro/etc/rc.conf
install -m 644 inittab /distro/etc/inittab
# Disable mounting devfs & cgroups, WSL does that for us.
echo 'skip_mount_dev="YES"' >> /distro/etc/conf.d/devfs
echo 'rc_cgroup_mode="none"' >> /distro/etc/conf.d/cgroups

# Add init script
install -D wsl-service /distro/usr/local/bin/wsl-service

# Create default runlevels
chroot /distro /sbin/rc-update add machine-id sysinit
echo 'rc_need="!dev"' >> /distro/etc/conf.d/machine-id

# Add logrotate
apk --root /distro add logrotate
install crond.initd /distro/etc/init.d/crond
chroot /distro /sbin/rc-update add crond default

# Create the root user (and delete all other users)
echo 'root:x:0:0:root:/root:/bin/sh' > /distro/etc/passwd
echo 'docker:x:101:root' > /distro/etc/group
# The UUCP group is needed internally by OpenRC for /run/lock.
# https://github.com/OpenRC/openrc/blob/openrc-0.13.11/sh/init.sh.Linux.in#L71
echo 'uucp:x:14:root' >> /distro/etc/group
mkdir -p /distro/root
cp /profile /distro/root/.profile

# Add default CA certificates (and update-ca-certificates).
apk --root /distro add ca-certificates
# We don't need the cert symlinks; they'll get regenerated on start.
find /distro/etc/ssl/certs -type l -delete

# Install nerdctl
tar -xvf /nerdctl.tgz -C /distro/usr/local/ \
  bin/buildctl \
  bin/buildkitd \
  bin/nerdctl

# Move nerdctl to /usr/local/libexec and replace it with a wrapper,
# so we can later setup environment variables for nerdctl in there.
mkdir -p /distro/usr/local/libexec/nerdctl
mv /distro/usr/local/bin/nerdctl /distro/usr/local/libexec/nerdctl/
cat <<EOF > /distro/usr/local/bin/nerdctl
#!/bin/sh
exec /usr/local/libexec/nerdctl/nerdctl "\$@"
EOF
chmod 755 /distro/usr/local/bin/nerdctl

# Add zoneinfo database (used by k8s CronJob controller)
apk --root /distro add tzdata

# Add packages required for nerdctl
apk --root /distro add iptables ip6tables iptables-legacy
apk --root /distro add tini-static
ln -s /sbin/tini-static /distro/usr/bin/tini

# Add dnsmasq
apk --root /distro add dnsmasq
mkdir -p /distro/var/lib/misc
chroot /distro /sbin/rc-update add dnsmasq default

# Install cri-dockerd
mkdir /cri-dockerd
tar -xvf /cri-dockerd.tgz -C /cri-dockerd
mv /cri-dockerd/cri-dockerd/cri-dockerd /distro/usr/local/bin/
# Copy the LICENSE file for cri-dockerd
mkdir -p /distro/usr/share/doc/cri-dockerd/
cp /cri-dockerd.LICENSE /distro/usr/share/doc/cri-dockerd/LICENSE
rm -rf /cri-dockerd

# Add Moby components
apk --root /distro add docker-engine docker-cli docker-cli-buildx
apk --root /distro add cni-plugins
apk --root /distro add cni-plugin-flannel
apk --root /distro add curl # for healthcheck
apk --root /distro add socat # for `kubectl port-forward` using docker-shim
apk --root /distro add xz # so `docker buildx` can extract files from tar.xz files

# Create required directories
install -d /distro/var/log
ln -s /run /distro/var/run

apk --root /distro add apk-tools
apk --root /distro add curl
apk --root /distro add sudo
apk --root /distro add git # so docker-compose can use a git URL
apk --root /distro add zstd # because `docker load` doesn't support .tar.zst files
apk --root /distro add tar # because `nerdctl cp` needs GNU tar
apk --root /distro add containerd-ctr # needed to copy files to the host
apk --root /distro add iproute2-minimal # For `ip -json`

# mkcert is used by the image-allow-list feature
apk --root /distro add mkcert --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing

# add openresty with http-proxy-connect module for the image-allow-list feature
cp /openresty/rd-openresty-*.pub /distro/etc/apk/keys
apk --root /distro add --force-non-repository /openresty/x86_64/*.apk

# Override iptables to support older kernels
cp /iptables-stub /distro/usr/local/bin/iptables-stub
chmod a+x /distro/usr/local/bin/iptables-stub
for family in iptables ip6tables; do
  for suffix in '' -save -restore; do
    ln -sfT /usr/local/bin/iptables-stub "/distro/sbin/${family}${suffix}"
  done
done

# Clean up apk metadata and other unneeded files
rm -rf /distro/var/cache/apk
rm -rf /distro/etc/network

# Generate /etc/os-release; we do it this way to evaluate variables.
. /os-release
rm -f /distro/etc/os-release # Remove the existing Alpine one
for field in $(awk -F= '/=/{ print $1 }' /os-release); do
  value="$(eval "echo \${${field}}")"
  if [ -n "${value}" ]; then
    echo "${field}=\"${value}\"" >> /distro/etc/os-release
  fi
done

# Configuration for WSL compatibility
install -m 644 wsl.conf /distro/etc/wsl.conf
