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

# add fun error pages & LetsEncrypt challenge directory outside webroot
RUN apk --no-cache add git \
    && cd /usr/share/nginx \
    && rm -rf html/* \
    && git clone https://git.asifbacchus.app/asif/fun-errorpages.git /tmp \
    && apk del git \
    && mv /tmp/errorpages/ ./ \
    && rm -rf /tmp/* \
    && rm -rf /tmp/.git*

# health check
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
    CMD curl --fail http://127.0.0.1:9000 || exit 1

# standardized labels
LABEL maintainer="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.label-schema.cmd="docker run -d --rm --name ab-nginx [--env-file ab-nginx.params] [-v /my_certs:/certs] [-v /my_nginx_config_files:/etc/nginx/config] [-v /my_nginx_server_blocks:/etc/nginx/sites] [-v /my_html_stuff:/usr/share/nginx/html] docker.asifbacchus.app/nginx/ab-nginx"
LABEL org.label-schema.description="NGINX-mainline-alpine with more logical file location layout and automatic SSL set up if certificates are provided."
LABEL org.label-schema.name="ab-nginx"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.url="https://git.asifbacchus.app/ab-docker/ab-nginx"
LABEL org.label-schema.usage="https://git.asifbacchus.app/ab-docker/ab-nginx/wiki"
LABEL org.label-schema.vcs-url="https://git.asifbacchus.app/ab-docker/ab-nginx.git"

# copy configuration files
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
LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL app.asifbacchus.docker.internalVersion="3.0"
LABEL org.label-schema.version="1.19.6"