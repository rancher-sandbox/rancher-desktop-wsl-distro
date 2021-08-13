#!/bin/sh

# This is a shell script that generates the target files in /distro

# shellcheck disable=SC3010

set -o errexit -o nounset -o xtrace

apk add -U ca-certificates

# Recursively find all package needed for ca-certificates
packages=" ca-certificates "

while true; do
  new_packages=""
  for package in ${packages}; do
    for dep in $(apk info --quiet --depends "${package}"); do
      if [[ "${packages}" != *" ${dep} "* ]]; then
        new_packages="${dep} ${new_packages}"
      fi
    done
  done
  if [[ -n "${new_packages}" ]]; then
    packages="${packages}${new_packages}"
  else
    break
  fi
done

# Copy files into the distro
mkdir -p /distro/bin
cp /bin/busybox /distro/bin/

for n in $(busybox --list); do
  if [ ! -e "/distro/bin/${n}" ]; then
    ln -s busybox "/distro/bin/${n}"
  fi
done

for package in ${packages}; do
  if [ "${package}" = "/bin/sh" ]; then
    continue # Skip /bin/sh, this is provideded by busybox
  fi
  for path in $(apk info --quiet --contents "${package}"); do
    mkdir -p "/distro/${path%/*}"
    cp -P "/${path}" "/distro/${path}"
  done
done

# Add directory for update-ca-certs
mkdir -p \
  /distro/etc/ssl/certs \
  /distro/usr/local/share/ca-certificates \
  /distro/tmp
chmod a+rwx /tmp

# Copy in the initial certificates
cp /etc/ssl/certs/ca-certificates.crt /distro/etc/ssl/certs/

# Create the root user
echo root:x:0:0:root:/root:/bin/sh > /distro/etc/passwd

# Generate /etc/os-release; we do it this way to evaluate variables.
. /os-release
for field in $(awk -F= '/=/{ print $1 }' /os-release); do
  value="$(eval "echo \${${field}}")"
  if [ -n "${value}" ]; then
    echo "${field}=\"${value}\"" >> /distro/etc/os-release
  fi
done
