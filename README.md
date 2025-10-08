# httpd-base

A simple Apache httpd implementation for fast website deployment.

[![Docker Image CI](https://github.com/napalmz/httpd-base/actions/workflows/main.yml/badge.svg)](https://github.com/napalmz/httpd-base/actions/workflows/main.yml)

Usage example:

```
services:
  httpd-server:
    image: napalmzrpi/httpd-base:latest
    container_name: httpd-server
    environment:
      - TZ=Europe/Rome
      - LOGROTATE_INTERVAL=daily #Optional
      - LOGROTATE_SIZE=100M      #Optional
      - LOGROTATE_ROTATE=7       #Optional
      - LOGROTATE_COMPRESS=1     #Optional
    volumes:
      - /your/dir/www/source:/var/www/site
      - /your/dir/www/log:/var/log/apache2
    ports:
      - 80:80
    restart: unless-stopped
```
