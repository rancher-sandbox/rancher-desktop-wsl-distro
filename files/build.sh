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
install -D wsl-init /distro/usr/local/bin/wsl-init
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

# Add default CA certificates (and update-ca-certificates).
apk --root /distro add ca-certificates
# We don't need the cert symlinks; they'll get regenerated on start.
find /distro/etc/ssl/certs -type l -delete

# Install nerdctl
tar -xvf /nerdctl.tgz -C /distro/usr/local/ \
  bin/buildctl \
  bin/buildkitd \
  bin/nerdctl
# The cni-plugins package does not include the isolation plugin
tar -xvf /nerdctl.tgz -C /distro/usr/ \
  libexec/cni/isolation
# Add packages required for nerdctl
apk --root /distro add iptables ip6tables

# Add dnsmasq
apk --root /distro add dnsmasq
mkdir -p /distro/var/lib/misc
chroot /distro /sbin/rc-update add dnsmasq default

# Add guest agent
install rancher-desktop-guestagent /distro/usr/local/bin
install rancher-desktop-guestagent.initd /distro/etc/init.d/rancher-desktop-guestagent
chroot /distro /sbin/rc-update add rancher-desktop-guestagent default

# Install cri-dockerd
mkdir -p /distro/usr/share/doc/cri-dockerd/
mkdir -p /distro/cri-dockerd/
tar -xvf /cri-dockerd.tgz -C /distro/cri-dockerd
chmod u+s /distro/cri-dockerd/cri-dockerd
cp /distro/cri-dockerd/cri-dockerd /distro/usr/local/bin/
# Copy the LICENSE file for cri-dockerd
mkdir -p /distro/usr/share/doc/cri-dockerd/
cp /distro/cri-dockerd/LICENSE /distro/usr/share/doc/cri-dockerd/
rm -rf /distro/cri-dockerd

# Add Moby components
apk --root /distro add docker-engine docker-cli
apk --root /distro add cni-plugins # instead of using nerdctl plugins because we need flannel and loopback too
apk --root /distro add cni-plugin-flannel --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
ln -s flannel-amd64 /distro/usr/libexec/cni/flannel
apk --root /distro add curl # for healthcheck
apk --root /distro add socat # for `kubectl port-forward` using docker-shim
apk --root /distro add xz # so `docker buildx` can extract files from tar.xz files

# Create required directories
install -d /distro/var/log
ln -s /run /distro/var/run

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
