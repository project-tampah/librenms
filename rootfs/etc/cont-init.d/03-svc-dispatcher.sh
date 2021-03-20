#!/usr/bin/with-contenv bash

. ../../utils/file_env.sh --source-only

SIDECAR_DISPATCHER=${SIDECAR_DISPATCHER:-0}

REDIS_SENTINEL_SERVICE=${REDIS_SENTINEL_SERVICE:-librenms}
file_env 'REDIS_PASSWORD'

# Continue only if sidecar dispatcher container
if [ "$SIDECAR_DISPATCHER" != "1" ]; then
    exit 0
fi

echo ">>"
echo ">> Sidecar dispatcher container detected"
echo ">>"

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
while ! ${dbcmd} -e "desc $MYSQL_DATABASE.poller_cluster;" >/dev/null 2>&1; do
    sleep 1
    counter=$((counter + 1))
    if [ ${counter} -gt ${MYSQL_TIMEOUT} ]; then
        echo >&2 "ERROR: Table $MYSQL_DATABASE.poller_cluster does not exist on $MYSQL_HOST"
        exit 1
    fi
done

# Node ID
if [ ! -f "/data/.env" ]; then
    echo >&2 "ERROR: /data/.env file does not exist. Please run the main container first"
    exit 1
fi
cat "/data/.env" >>"${LIBRENMS_PATH}/.env"
if [ -n "$DISPATCHER_NODE_ID" ]; then
    echo "NODE_ID: $DISPATCHER_NODE_ID"
    sed -i "s|^NODE_ID=.*|NODE_ID=$DISPATCHER_NODE_ID|g" "${LIBRENMS_PATH}/.env"
fi

# Redis
if [ -z "$REDIS_HOST" ] && [ -z "$REDIS_SENTINEL" ]; then
    echo >&2 "ERROR: REDIS_HOST or REDIS_SENTINEL must be defined"
    exit 1
elif [ -n "$REDIS_HOST" ]; then
    echo "Setting Redis"
    cat >>${LIBRENMS_PATH}/.env <<EOL
REDIS_HOST=${REDIS_HOST}
REDIS_SCHEME=${REDIS_SCHEME}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=${REDIS_DB}
EOL
elif [ -n "$REDIS_SENTINEL" ]; then
    echo "Setting Redis Sentinel"
    cat >>${LIBRENMS_PATH}/.env <<EOL
REDIS_SENTINEL=${REDIS_SENTINEL}
REDIS_SENTINEL_SERVICE=${REDIS_SENTINEL_SERVICE}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=${REDIS_DB}
EOL
fi

# Create service
mkdir -p /etc/services.d/dispatcher
cat >/etc/services.d/dispatcher/run <<EOL
#!/usr/bin/execlineb -P
with-contenv
s6-setuidgid ${PUID}:${PGID}
${LIBRENMS_PATH}/librenms-service.py ${DISPATCHER_ARGS}
EOL
chmod +x /etc/services.d/dispatcher/run
