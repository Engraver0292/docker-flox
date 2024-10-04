FROM mwalbeck/supercronic:0.2.32@sha256:efd43e21077db1d361bd6f25467e0f835f4b635f04a3caf39ded5e85d88fba90 as supercronic

FROM mwalbeck/composer:2-php8.2@sha256:5bbe9d0e2442aa78928e3042758bd743734b54a85a8405ca1060bff2e870c346 AS composer

ENV FLOX_VERSION=main

RUN set -ex; \
    \
    git clone --branch $FLOX_VERSION https://github.com/Simounet/flox.git /tmp/flox; \
    cd /tmp/flox/backend; \
    composer --no-cache install;

FROM php:8.2-fpm-bullseye@sha256:7f8b58226902acff98b51fa81ccc0d515bd93a40a63868d4d0206ac7b5b5ac92

COPY --from=composer /tmp/flox /usr/share/flox
COPY --from=supercronic /supercronic /usr/local/bin/supercronic

RUN set -ex; \
    \
    groupadd --system foo; \
    useradd --no-log-init --system --gid foo --create-home foo; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        supervisor \
        gosu \
        sqlite3 \
        rsync \
        libpq5 \
        libpq-dev \
    ; \
    chmod +x /usr/local/bin/supercronic; \
    echo '* * * * * php /var/www/flox/backend/artisan schedule:run >> /dev/null 2>&1' > /crontab; \
    \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    \
    { \
        echo "upload_max_filesize=128M"; \
        echo "post_max_size=128M"; \
    } > /usr/local/etc/php/conf.d/flox.ini; \
    \
    mkdir -p \
        /var/log/supervisord \
        /var/run/supervisord \
        /var/www/flox \
    ; \
    docker-php-ext-install -j "$(nproc)" \
        bcmath \
        pdo_mysql \
        pdo_pgsql \
        opcache \
    ; \
    apt-get purge -y --autoremove libpq-dev; \
    rm -rf /var/lib/apt/lists/*;

COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /supervisord.conf

VOLUME [ "/var/www/flox" ]
WORKDIR /var/www/flox

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
