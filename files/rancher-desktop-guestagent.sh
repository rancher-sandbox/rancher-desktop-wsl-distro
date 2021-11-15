#!/sbin/openrc-run

# This script is used on WSL to manage the guest agent.

# shellcheck shell=ksh

depend() {
  after network-online
}

supervisor=supervise-daemon
name="Rancher Desktop Guest Agent"
command=/usr/local/bin/rancher-desktop-guestagent
output_log=/var/log/guestagent
error_log=/var/log/guestagent

respawn_delay=5
respawn_max=0

set -o allexport
if [ -f /etc/environment ]; then source /etc/environment; fi
