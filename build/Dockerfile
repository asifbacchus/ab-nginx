FROM nginx:mainline-alpine

# add fun error pages & LetsEncrypt challenge directory outside webroot
RUN apk --no-cache add git \
    && cd /usr/share/nginx \
    && rm -rf html/* \
    && git clone https://git.asifbacchus.app/asif/fun-errorpages.git /tmp \
    && apk del git \
    && mv /tmp/errorpages/ ./ \
    && rm -rf /tmp/* \
    && rm -rf /tmp/.git*

# standardized labels
LABEL maintainer="Asif Bacchus <asif@bacchus.cloud>"
LABEL org.label-schema.cmd="docker run -d --name ab-nginx [--env-file ab-nginx.params] [-v certs:/certs] ab-nginx"
LABEL org.label-schema.description="NGINX-mainline-alpine with more logical file location layout and automatic SSL set up if certificates are provided."
LABEL org.label-schema.name="ab-nginx"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.url="https://git.asifbacchus.app/ab-docker/ab-nginx"
LABEL org.label-schema.usage="https://git.asifbacchus.app/ab-docker/ab-nginx/wiki"
LABEL org.label-schema.vcs-url="https://git.asifbacchus.app/ab-docker/ab-nginx.git"
LABEL org.label-schema.version="0.1-beta"

# copy configuration files
COPY entrypoint.sh /entrypoint.sh
COPY config /etc/nginx/
COPY sites /etc/nginx/sites/
COPY webroot /usr/share/nginx/html/

# expose ports
EXPOSE 80 443

# default environment variables
ENV SERVER_NAMES="_"
ENV HTTP_PORT=80
ENV HTTPS_PORT=443
ENV HSTS=FALSE
ENV TLS13_ONLY=FALSE

# entrypoint script
ENTRYPOINT [ "/entrypoint.sh" ]

# run NGINX by default
CMD [ "nginx", "-g", "daemon off;" ]

# add build date label
ARG BUILD_DATE
LABEL org.label-schema.build-date=${BUILD_DATE}
