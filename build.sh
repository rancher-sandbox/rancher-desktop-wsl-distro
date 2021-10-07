#!/bin/sh

# This is a shell script that generates the target files in /distro

# shellcheck shell=ash

set -o errexit -o nounset -o xtrace

# Bootstrap an alpine chroot in /distro
apk add -U alpine-conf
mkdir /distro
lbu package - | tar -C /distro -zx
# Remove unnecessary packages
rm -f /distro/etc/apk/world
apk --root /distro --update-cache add --initdb busybox

apk --root /distro add ca-certificates

# We don't need the cert symlinks; they'll get regenerated on start.
find /distro/etc/ssl/certs -type l -delete

# Install nerdctl
tar -xvf /nerdctl.tgz -C /distro/usr/local/ \
  bin/buildctl \
  bin/buildkitd \
  bin/nerdctl \
  libexec/cni/bridge \
  libexec/cni/portmap \
  libexec/cni/firewall \
  libexec/cni/tuning \
  libexec/cni/isolation \
  libexec/cni/host-local
# Add packages required for nerdctl
apk --root /distro add iptables ip6tables

# Add guest agent
chmod +x rancher-desktop-guestagent
cp rancher-desktop-guestagent /distro/usr/local/bin/

# Create the root user (and delete all other users)
echo root:x:0:0:root:/root:/bin/sh > /distro/etc/passwd

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
cp wsl.conf /distro/etc/wsl.conf
