#!/bin/sh

#
### ab-nginx entrypoint script
#

### update configuration files with environment variables
# update server name list
printf "\nUpdating server name list... "
sed -i -e "s%<SERVER_NAMES>%${SERVER_NAMES}%" /etc/nginx/server_names.conf
printf "done\n"

# update access log global preference
if [ "$ACCESS_LOG" = "OFF" ]; then
    printf "Turning access log OFF... "
    sed -i -e "s%<ACCESS_LOG_SETTING>%OFF%" /etc/nginx/nginx.conf
    printf "done\n"
elif [ "$ACCESS_LOG" = "ON" ]; then
    printf "Turning access log ON... "
    sed -i -e "s%<ACCESS_LOG_SETTING>%/var/log/nginx/access.log combined%" /etc/nginx/nginx.conf
    printf "done\n"
fi

# update HTTPS redirect port if SSL server test block exists
if [ -f "/etc/nginx/sites/note" ]; then
    printf "Updating port redirects... "
    sed -i -e "s%<HTTPS_PORT>%${HTTPS_PORT}%" /etc/nginx/sites/05-test_secured.conf.disabled
    printf "done\n"
fi

# activate HSTS
if [ "$HSTS" = TRUE ]; then
    printf "Activating HSTS configuration... "
    sed -i -e "s/^#add_header/add_header/" \
        /etc/nginx/ssl-config/mozIntermediate_ssl.conf.disabled
    sed -i -e "s/^#add_header/add_header/" \
        /etc/nginx/ssl-config/mozModern_ssl.conf.disabled
    printf "done\n"
fi

# activate SSL configuration as appropriate and only if certs exist
if [ "$TLS13_ONLY" = FALSE ]; then
    if [ -f "/certs/fullchain.pem" ] && \
        [ -f "/certs/privkey.pem" ] && \
        [ -f "/certs/chain.pem" ] && \
        [ -f "/certs/dhparam.pem" ]; then
            printf "Certificates found. Securing deployment using TLS 1.2\n"

            # activate shared SSL configuration file
            mv /etc/nginx/ssl-config/mozIntermediate_ssl.conf.disabled \
                /etc/nginx/ssl-config/mozIntermediate_ssl.conf
            
            if [ -f "/etc/nginx/sites/note" ]; then
                # activate SSL test server block & deactivate normal one
                mv /etc/nginx/sites/05-test_secured.conf.disabled \
                    /etc/nginx/sites/05-test_secured.conf
                mv /etc/nginx/sites/05-test_nonsecured.conf \
                    /etc/nginx/sites/05-test_nonsecured.conf.disabled
            fi
    fi
elif [ "$TLS13_ONLY" = TRUE ]; then
    if [ -f "/certs/fullchain.pem" ] && \
        [ -f "/certs/privkey.pem" ] && \
        [ -f "/certs/chain.pem" ]; then
            printf "Certificates found. Securing deployment using TLS 1.3\n"

            # activate shared SSL configuration file
            mv /etc/nginx/ssl-config/mozModern_ssl.conf.disabled \
                /etc/nginx/ssl-config/mozModern_ssl.conf
            
            if [ -f "/etc/nginx/sites/note" ]; then
                # activate SSL test server block & deactivate normal one
                mv /etc/nginx/sites/05-test_secured.conf.disabled \
                    /etc/nginx/sites/05-test_secured.conf
                mv /etc/nginx/sites/05-test_nonsecured.conf \
                    /etc/nginx/sites/05-test_nonsecured.conf.disabled
            fi
    fi
fi

# execute commands passed to this container
printf "\nSetup complete...Container ready...\n"
exec "$@"

#EOF