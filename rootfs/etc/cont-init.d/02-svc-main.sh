#!/usr/bin/with-contenv bash

. ../../utils/file_env.sh --source-only

SIDECAR_DISPATCHER=${SIDECAR_DISPATCHER:-0}
SIDECAR_SYSLOGNG=${SIDECAR_SYSLOGNG:-0}
SIDECAR_SNMPTRAPD=${SIDECAR_SNMPTRAPD:-0}

if [ "$SIDECAR_DISPATCHER" = "1" ] || [ "$SIDECAR_SYSLOGNG" = "1" ] || [ "$SIDECAR_SNMPTRAPD" = "1" ]; then
    exit 0
fi

# Handle .env
if [ ! -f "/data/.env" ]; then
    echo "Generating APP_KEY and unique NODE_ID"
    cat >"/data/.env" <<EOL
APP_KEY=$(artisan key:generate --no-interaction --force --show)
NODE_ID=$(php -r "echo uniqid();")
EOL
fi
cat "/data/.env" >>"${LIBRENMS_PATH}/.env"
chown librenms:librenms /data/.env "${LIBRENMS_PATH}/.env"

file_env 'MYSQL_PASSWORD'
if [ -z "$MYSQL_PASSWORD" ]; then
    echo >&2 "ERROR: Either MYSQL_PASSWORD or MYSQL_PASSWORD_FILE must be defined"
    exit 1
fi

dbcmd="mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u "${MYSQL_USER}" "-p${MYSQL_PASSWORD}""
unset MYSQL_PASSWORD

echo "Waiting ${MYSQL_TIMEOUT}s for database to be ready..."
counter=1
while ! ${dbcmd} -e "show databases;" >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ ${counter} -gt ${MYSQL_TIMEOUT} ]; then
        echo >&2 "ERROR: Failed to connect to database on $MYSQL_HOST"
        exit 1
    fi
done
echo "Database ready!"
counttables=$(echo 'SHOW TABLES' | ${dbcmd} "$MYSQL_DATABASE" | wc -l)

echo "Updating database schema..."
lnms migrate --force --no-ansi --no-interaction
artisan db:seed --force --no-ansi --no-interaction

echo "Clear cache"
artisan cache:clear --no-interaction
artisan config:cache --no-interaction

if [ "${counttables}" -eq "0" ]; then
    echo "Creating admin user..."
    lnms user:add --password=librenms --email=librenms@librenms.docker --role=admin --no-ansi --no-interaction librenms
fi

mkdir -p /etc/services.d/nginx
cat >/etc/services.d/nginx/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
s6-setuidgid ${PUID}:${PGID}
nginx -g "daemon off;"
EOL
chmod +x /etc/services.d/nginx/run

mkdir -p /etc/services.d/php-fpm
cat >/etc/services.d/php-fpm/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
s6-setuidgid ${PUID}:${PGID}
php-fpm8 -F
EOL
chmod +x /etc/services.d/php-fpm/run

mkdir -p /etc/services.d/snmpd
cat >/etc/services.d/snmpd/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
/usr/sbin/snmpd -f -c /etc/snmp/snmpd.conf
EOL
chmod +x /etc/services.d/snmpd/run
