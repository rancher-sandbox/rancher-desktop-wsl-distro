#!/sbin/openrc-run

# This is a replacement for the default /etc/init.d/crond to run crond in a
# container.

CROND_LOGFILE="${CROND_LOGFILE:-${LOG_DIR:-/var/log}/${RC_SVCNAME}.log}"

supervisor=supervise-daemon
name="busybox $SVCNAME"
command="/usr/sbin/$SVCNAME"
command_args="$CRON_OPTS -f -L /dev/stdout"
output_log="${CROND_LOGFILE}"
error_log="${CROND_LOGFILE}"

depend() {
    need localmount
}

start_pre() {
    mkdir -p /var/spool/cron/crontabs

  cat > /etc/logrotate.d/crond <<EOF
  ${CROND_LOGFILE} {
    missingok
    notifempty
  }
EOF
}
