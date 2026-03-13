FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apache2 \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod proxy proxy_http ssl headers rewrite

COPY vhost.conf /etc/apache2/sites-available/000-default.conf
COPY index.html /var/www/html/index.html

RUN a2ensite 000-default

EXPOSE 80 443

CMD ["apache2ctl", "-D", "FOREGROUND"]
