#!/usr/bin/with-contenv sh

# Fix access rights to stdout and stderr
chown ${PUID}:${PGID} /proc/self/fd/1 /proc/self/fd/2 || true

###########
# Fix uid #
###########
if [ -n "${PGID}" ] && [ "${PGID}" != "$(id -g librenms)" ]; then
    echo "Switching to PGID ${PGID}..."
    sed -i -e "s/^librenms:\([^:]*\):[0-9]*/librenms:\1:${PGID}/" /etc/group
    sed -i -e "s/^librenms:\([^:]*\):\([0-9]*\):[0-9]*/librenms:\1:\2:${PGID}/" /etc/passwd
fi
if [ -n "${PUID}" ] && [ "${PUID}" != "$(id -u librenms)" ]; then
    echo "Switching to PUID ${PUID}..."
    sed -i -e "s/^librenms:\([^:]*\):[0-9]*:\([0-9]*\)/librenms:\1:${PUID}:\2/" /etc/passwd
fi

#############
# Fix perms #
#############
echo "Fixing perms..."
mkdir -p /data \
    /var/run/nginx \
    /var/run/php-fpm
chown librenms:librenms \
    /data \
    "${LIBRENMS_PATH}" \
    "${LIBRENMS_PATH}/.env" \
chown -R librenms:librenms \
    /home/librenms \
    /tpls \
    /var/lib/nginx \
    /var/log/nginx \
    /var/log/php8 \
    /var/run/nginx \
    /var/run/php-fpm
