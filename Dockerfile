FROM ubuntu:latest
LABEL maintainer="NapalmZ <admin@napalmz.eu>"

# PHP Version
ENV PHPVER=8.2.3
ENV TZ=Europe/Rome

# Install apache, PHP, and supplimentary programs. curl and lynx-cur are for debugging the container.
RUN apt-get update && apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common && \
    add-apt-repository ppa:ondrej/php -y && \
    apt-get update && apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    curl lynx-common tzdata \
    apache2 \
    php${PHPVER} php${PHPVER}-mysql libapache2-mod-php${PHPVER}

# Enable apache mods.
RUN a2enmod php${PHPVER}
RUN a2enmod rewrite

# Update the PHP.ini file, enable <? ?> tags and quieten logging.
RUN sed -i -r "s/short_open_tag = Off/short_open_tag = On/g" /etc/php/${PHPVER}/apache2/php.ini
#RUN sed -i -r "s/error_reporting = .*$/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/g" /etc/php/${PHPVER}/apache2/php.ini

# Manually set up the apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

# Expose apache.
EXPOSE 80

# Setup HEALTHCHECK.
HEALTHCHECK CMD curl --fail http://localhost:80 || exit 1

# Copy this repo into place.
ADD www /var/www/site

# Update the default apache site with the config we created.
ADD apache-config.conf /etc/apache2/sites-enabled/000-default.conf

# By default start up apache in the foreground, override with /bin/bash for interative.
CMD /usr/sbin/apache2ctl -D FOREGROUND
