#!/usr/bin/with-contenv bash

CRONTAB_PATH="/var/spool/cron/crontabs"

LIBRENMS_DAILY_SCHEDULE=${LIBRENMS_DAILY_SCHEDULE:-"15 0 * * *"}

SIDECAR_DISPATCHER=${SIDECAR_DISPATCHER:-0}
SIDECAR_SYSLOGNG=${SIDECAR_SYSLOGNG:-0}
SIDECAR_SNMPTRAPD=${SIDECAR_SNMPTRAPD:-0}

if [ "$SIDECAR_DISPATCHER" = "1" ] || [ "$SIDECAR_SYSLOGNG" = "1" ] || [ "$SIDECAR_SNMPTRAPD" = "1" ]; then
  exit 0
fi

# Init
rm -rf ${CRONTAB_PATH}
mkdir -m 0644 -p ${CRONTAB_PATH}
touch ${CRONTAB_PATH}/librenms

# Cron
echo "Creating LibreNMS daily.sh cron task with the following period fields: $LIBRENMS_DAILY_SCHEDULE"
echo "${LIBRENMS_DAILY_SCHEDULE} cd ${LIBRENMS_PATH} && bash daily.sh" >>${CRONTAB_PATH}/librenms

# Fix perms
echo "Fixing crontabs permissions..."
chmod -R 0644 ${CRONTAB_PATH}

# Create service
mkdir -p /etc/services.d/cron
cat >/etc/services.d/cron/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
exec busybox crond -f -L /dev/stdout
EOL
chmod +x /etc/services.d/cron/run
