FROM nginx:mainline-alpine

# default uid and gid for nginx user
ARG UID=8080
ARG GID=8080

# create nginx user
RUN addgroup --gid ${GID} www-docker \
    && adduser \
        -S \
        -h /home/www-docker \
        -G www-docker \
        --disabled-password \
        --gecos 'nginx docker system user' \
        --uid ${UID} \
        www-docker

# add libcap, allow nginx to bind to ports <1024, extract fun error pages & create LetsEncrypt challenge directory outside webroot
RUN apk --no-cache add libcap \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx \
    && cd /usr/share/nginx \
    && rm -rf html/* \
    && wget -O /tmp/errorpages.tar.gz https://git.asifbacchus.app/asif/fun-errorpages/archive/v1.0.tar.gz \
    && tar -xzf /tmp/errorpages.tar.gz -C /tmp \
    && mv /tmp/fun-errorpages/errorpages ./ \
    && rm -rf /tmp/* \
    && rm -rf /docker-entrypoint.d \
    && rm -f /docker-entrypoint.sh \
    && mkdir /usr/share/nginx/letsencrypt

# health check
HEALTHCHECK \
    --interval=10s \
    --timeout=5s \
    --start-period=60s \
    --retries=3 \
    CMD curl --fail http://127.0.0.1:9000/nginx_status || exit 1

# standardized labels
MAINTAINER "Asif Bacchus <asif@bacchus.cloud>"
LABEL maintainer="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.opencontainers.image.author="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.opencontainers.image.url="https://git.asifbacchus.app/ab-docker/ab-nginx"
LABEL org.opencontainers.image.documentation="https://git.asifbacchus.app/ab-docker/ab-nginx/wiki"
LABEL org.opencontainers.image.source="https://git.asifbacchus.app/ab-docker/ab-nginx.git"
LABEL org.opencontainers.image.vendor="NGINX"
LABEL org.opencontainers.image.title="ab-nginx"
LABEL org.opencontainers.image.description="NGINX-mainline-alpine with more logical file location layout and automatic SSL set up if certificates are provided."

# copy configuration files
COPY entrypoint.sh /entrypoint.sh
COPY config /etc/nginx/
COPY sites /etc/nginx/sites/
COPY webroot /usr/share/nginx/html/

# expose ports
EXPOSE 80 443

# clean-up permissions and run as www-docker user
RUN chown -R www-docker:www-docker /usr/share/nginx \
    && find /usr/share/nginx -type d -exec chmod 755 {} \; \
    && find /usr/share/nginx -type f -exec chmod 644 {} \; \
    && chown -R www-docker:www-docker /etc/nginx \
    && find /etc/nginx -type d -exec chmod 750 {} \; \
    && find /etc/nginx -type f -exec chmod 640 {} \; \
    && chown www-docker:www-docker /var/cache/nginx \
    && chown www-docker:www-docker /var/log/nginx
USER www-docker
WORKDIR /usr/share/nginx/html

# default environment variables
ENV TZ=Etc/UTC
ENV SERVER_NAMES="_"
ENV HTTP_PORT=80
ENV HTTPS_PORT=443
ENV ACCESS_LOG=OFF
ENV HSTS=FALSE
ENV TLS13_ONLY=FALSE

# entrypoint script
ENTRYPOINT [ "/entrypoint.sh" ]

# run NGINX by default
STOPSIGNAL SIGQUIT
CMD [ "nginx", "-g", "daemon off;" ]

# add build date and version labels
ARG BUILD_DATE
LABEL org.opencontainers.image.version="1.21.1"
LABEL app.asifbacchus.docker.internalVersion="5.0-1.21.1"
LABEL org.opencontainers.image.created=${BUILD_DATE}

#EOF
