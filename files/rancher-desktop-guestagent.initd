#!/sbin/openrc-run

# This script is used on WSL to manage the guest agent.

# shellcheck shell=ksh

depend() {
  after network-online
}

GUESTAGENT_LOGFILE="${GUESTAGENT_LOGFILE:-${LOG_DIR:-/var/log}/${RC_SVCNAME}.log}"

supervisor=supervise-daemon
name="Rancher Desktop Guest Agent"
command=/usr/local/bin/rancher-desktop-guestagent
output_log="${GUESTAGENT_LOGFILE}"
error_log="${GUESTAGENT_LOGFILE}"

respawn_delay=5
respawn_max=0

start_pre() {
  cat > /etc/logrotate.d/guestagent <<EOF
  ${GUESTAGENT_LOGFILE} {
    missingok
    notifempty
  }
EOF
}

set -o allexport
if [ -f /etc/environment ]; then source /etc/environment; fi
