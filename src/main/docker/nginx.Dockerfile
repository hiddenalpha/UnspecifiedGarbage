#
# Bare nginx server serving HTTP/80 and HTTPS/443 from "/work/www".
#

ARG PARENT_IMAGE=alpine:3.16.0
FROM $PARENT_IMAGE

ARG CN=example.com
ARG PKGS_TO_ADD="nginx openssl"
ARG PKGS_TO_DEL="openssl"
ARG PKGINIT="true"
ARG PKGADD="apk add"
ARG PKGDEL="true"
ARG PKGCLEAN="true"

WORKDIR /work

RUN true \
    && $PKGINIT \
    && $PKGADD $PKGS_TO_ADD \
    && mkdir /work/www \
    && openssl genrsa -out /etc/ssl/private/nginx.key 2048 \
    && openssl req -new -key /etc/ssl/private/nginx.key \
         -out /etc/ssl/private/nginx.csr \
         -subj "/C=/ST=/L=/O=/OU=/CN=${CN:?}" \
    && openssl x509 -req -days 365 -in /etc/ssl/private/nginx.csr \
         -signkey /etc/ssl/private/nginx.key -out /etc/ssl/certs/nginx.crt \
    && chgrp nginx /etc/ssl/private/nginx.key \
    && chmod 0640 /etc/ssl/private/nginx.key \
    && printf 'server {\n\
    listen 80 default_server;\n\
    listen [::]:80 default_server;\n\
    listen 443 ssl default_server;\n\
    listen [::]:443 default_server;\n\
    ssl_certificate /etc/ssl/certs/nginx.crt;\n\
    ssl_certificate_key /etc/ssl/private/nginx.key;\n\
    location / {\n\
        root   /work/www;\n\
        index  index.html index.htm;\n\
    }\n\
}\n' > /etc/nginx/http.d/default.conf \
    && chown nginx:nginx /work /work/www \
    && $PKGDEL $PKGS_TO_DEL \
    && $PKGCLEAN \
    && true

USER nginx:nginx

CMD ["nginx", "-g", "daemon off;"]

