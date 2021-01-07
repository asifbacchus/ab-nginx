FROM nginx:mainline-alpine

# default username and uid for nginx user
ARG USER=www-docker
ARG UID=8001

# create nginx user
RUN addgroup --gid ${UID} ${USER} \
    && adduser \
        --disabled-password \
        --gecos 'nginx docker system user' \
        --home '/usr/share/nginx/html' \
        --ingroup ${USER} \
        --no-create-home \
        --uid ${UID} \
        ${USER}

# add nano, fun error pages & LetsEncrypt challenge directory outside webroot
RUN apk --no-cache add nano \
    && cd /usr/share/nginx \
    && rm -rf html/* \
    && wget -O /tmp/errorpages.tar.gz https://git.asifbacchus.app/asif/fun-errorpages/archive/v1.0.tar.gz \
    && tar -xzf /tmp/errorpages.tar.gz -C /tmp \
    && mv /tmp/fun-errorpages/errorpages ./ \
    && rm -rf /tmp/*

# health check
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
    CMD curl --fail http://127.0.0.1:9000/nginx_status || exit 1

# standardized labels
LABEL author="Asif Bacchus <asif@bacchus.cloud>"
LABEL maintainer="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.opencontainers.image.author="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.opencontainers.image.url="https://git.asifbacchus.app/ab-docker/ab-nginx"
LABEL org.opencontainers.image.documentation="https://git.asifbacchus.app/ab-docker/ab-nginx/wiki"
LABEL org.opencontainers.image.source="https://git.asifbacchus.app/ab-docker/ab-nginx.git"
LABEL org.opencontainers.image.vendor="NGINX"
LABEL org.opencontainers.image.title="ab-nginx"
LABEL org.opencontainers.image.description="NGINX-mainline-alpine with more logical file location layout and automatic SSL set up if certificates are provided."

# copy configuration files
COPY nanorc /etc/nanorc
COPY entrypoint.sh /entrypoint.sh
COPY config /etc/nginx/
COPY sites /etc/nginx/sites/
COPY webroot /usr/share/nginx/html/

# expose ports
EXPOSE 80 443

# clean-up permissions
RUN chown -R ${USER}:${USER} /usr/share/nginx/html \
    && find /usr/share/nginx/html -type d -exec chmod 775 {} \; \
    && find /usr/share/nginx/html -type f -exec chmod 664 {} \; \
    && chown -R ${USER}:${USER} /etc/nginx \
    && find /etc/nginx -type d -exec chmod 770 {} \; \
    && find /etc/nginx -type f -exec chmod 660 {} \;

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
CMD [ "nginx", "-g", "daemon off;" ]

# add build date and version labels
ARG BUILD_DATE
LABEL org.opencontainers.image.version="1.19.6"
LABEL app.asifbacchus.docker.internalVersion="3.0"
LABEL org.opencontainers.image.created=${BUILD_DATE}

#EOF