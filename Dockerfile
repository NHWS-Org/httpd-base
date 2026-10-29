FROM ubuntu:latest
LABEL maintainer="NapalmZ <admin@napalmz.eu>"

# PHP Version
ENV PHPVER=8.5
ENV TZ=Europe/Rome
ENV LOGROTATE_INTERVAL=daily \
    LOGROTATE_SIZE=100M \
    LOGROTATE_ROTATE=7 \
    LOGROTATE_COMPRESS=1

# Install Apache, PHP, and supplementary programs. Ubuntu Resolute ships PHP 8.5,
# so use its native packages instead of the Ondrej PPA, which has no Resolute suite.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
    curl lynx-common tzdata \
    apache2 \
    php${PHPVER} php${PHPVER}-mysql libapache2-mod-php${PHPVER} php${PHPVER}-gd php${PHPVER}-imagick \
    cron logrotate \
    tree nano && \
    rm -rf /var/lib/apt/lists/*

# Enable Apache modules.
RUN a2enmod php${PHPVER} && a2enmod rewrite

# Configure cron job for logrotate
RUN echo "*/15 * * * * root /usr/sbin/logrotate -s /var/lib/logrotate/status /etc/logrotate.conf" > /etc/cron.d/logrotate \
 && chmod 0644 /etc/cron.d/logrotate \
 && mkdir -p /var/lib/logrotate \
 && touch /var/lib/logrotate/status

# Update the PHP.ini file, enable <? ?> tags and quieten logging.
RUN sed -i -r "s/short_open_tag = Off/short_open_tag = On/g" /etc/php/${PHPVER}/apache2/php.ini
#RUN sed -i -r "s/error_reporting = .*$/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/g" /etc/php/${PHPVER}/apache2/php.ini

# Manually set up the apache environment variables
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_PID_FILE=/var/run/apache2.pid

# Expose apache.
EXPOSE 80

# Setup HEALTHCHECK.
HEALTHCHECK CMD curl --fail http://localhost:80 || exit 1

# Entrypoint to generate logrotate config from ENV and run cron
RUN printf '%s\n' "#!/bin/sh" \
             "set -eu" \
             ": \"\${LOGROTATE_ROTATE:=7}\"" \
             ": \"\${LOGROTATE_SIZE:=100M}\"" \
             ": \"\${LOGROTATE_INTERVAL:=daily}\"" \
             ": \"\${LOGROTATE_COMPRESS:=1}\"" \
             "# build /etc/logrotate.d/apache2 from ENV" \
             "cat > /etc/logrotate.d/apache2 <<'EOF'" \
             "/var/log/apache2/*.log {" \
             "    missingok" \
             "    notifempty" \
             "    copytruncate" \
             "    rotate ROTATECOUNT" \
             "    size SIZELIMIT" \
             "    # interval keyword injected below" \
             "    INTERVALKEYWORD" \
             "    compress" \
             "    delaycompress" \
             "}" \
             "EOF" \
             "sed -i s/ROTATECOUNT/\${LOGROTATE_ROTATE}/ /etc/logrotate.d/apache2" \
             "sed -i s/SIZELIMIT/\${LOGROTATE_SIZE}/ /etc/logrotate.d/apache2" \
             "case \"\${LOGROTATE_INTERVAL}\" in" \
             "  daily|weekly|monthly) sed -i s/INTERVALKEYWORD/\"\${LOGROTATE_INTERVAL}\"/ /etc/logrotate.d/apache2 ;;" \
             "  *) sed -i s/INTERVALKEYWORD/daily/ /etc/logrotate.d/apache2 ;;" \
             "esac" \
             "if [ \"\${LOGROTATE_COMPRESS}\" = \"0\" ]; then" \
             "  sed -i 's/^    compress/    nocompress/' /etc/logrotate.d/apache2" \
             "  sed -i '/delaycompress/d' /etc/logrotate.d/apache2" \
             "fi" \
             "# runtime perms fix (no directory creation)" \
             ": \"\${GALLERY_ROOT:=/var/www/site}\"" \
             ": \"\${FIX_PERMS:=1}\"" \
             ": \"\${APACHE_RUN_USER:=www-data}\"" \
             "if [ \"\${FIX_PERMS}\" = \"1\" ]; then" \
             "  if command -v setfacl >/dev/null 2>&1; then" \
             "    setfacl -Rm u:\${APACHE_RUN_USER}:rwx \"\${GALLERY_ROOT}\" || true" \
             "    setfacl -dm u:\${APACHE_RUN_USER}:rwx \"\${GALLERY_ROOT}\" || true" \
             "  else" \
             "    chmod -R a+rwX \"\${GALLERY_ROOT}\" || true" \
             "    find \"\${GALLERY_ROOT}\" -type d -exec chmod g+s {} \\; || true" \
             "  fi" \
             "fi" \
             "# start cron in background, then apache in the foreground" \
             "/usr/sbin/cron" \
             "exec /usr/sbin/apache2ctl -D FOREGROUND" \
             > /usr/local/bin/start-with-logrotate.sh \
 && chmod +x /usr/local/bin/start-with-logrotate.sh

# Copy this repo into place.
ADD www /var/www/site

# Update the default apache site with the config we created.
ADD apache-config.conf /etc/apache2/sites-enabled/000-default.conf

# By default start up apache in the foreground, override with /bin/bash for interactive use.
CMD ["/usr/local/bin/start-with-logrotate.sh"]
