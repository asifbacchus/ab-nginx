#!/bin/sh

#
### ab-nginx entrypoint script
#

### update configuration files with environment variables
# update server name list
printf "\nUpdating server name list... "
sed -i -e "s%<SERVER_NAMES>%${SERVER_NAMES}%" /etc/nginx/server_names.conf
printf "done\n"

# activate HSTS
if [ "$HSTS" = TRUE ]; then
    printf "Activating HSTS configuration... "
    sed -i -e "s/^#add_header/add_header/" \
        /etc/nginx/config/mozIntermediate_ssl.conf.disabled
    sed -i -e "s/^#add_header/add_header/" \
        /etc/nginx/config/mozModern_ssl.conf.disabled
    printf "done\n"
fi

# activate SSL configuration as appropraite and only if certs exist
if [ "$TLS13_ONLY" = FALSE ]; then
    if [ -f "/certs/fullchain.pem" ] && \
        [ -f "/certs/privkey.pem" ] && \
        [ -f "/certs/chain.pem" ] && \
        [ -f "/certs/dhparam.pem" ]; then
            printf "Certificates found. Securing deployment using TLS 1.2\n"

            # activate shared SSL configuration file
            mv /etc/nginx/config/mozIntermediate_ssl.conf.disabled \
                /etc/nginx/config/mozIntermediate_ssl.conf
            
            # activate SSL test server block if it exists
            if [ -f "/etc/nginx/sites/05-test-secured.conf" ]; then
                mv /etc/nginx/sites/05-test-secured.conf.disabled \
                    /etc/nginx/sites/05-test-secured.conf
            fi
    fi
elif [ "$TLS13_ONLY" = TRUE ]; then
    if [ -f "/certs/fullchain.pem" ] && \
        [ -f "/certs/privkey.pem" ] && \
        [ -f "/certs/chain.pem" ]; then
            printf "Certificates found. Securing deployment using TLS 1.3\n"

            # activate shared SSL configuration file
            mv /etc/nginx/config/mozModern_ssl.conf.disabled \
                /etc/nginx/config/mozModern_ssl.conf
            
            # activate SSL test server block if it exists
            if [ -f "/etc/nginx/sites/05-test-secured.conf" ]; then
                mv /etc/nginx/sites/05-test-secured.conf.disabled \
                    /etc/nginx/sites/05-test-secured.conf
            fi
    fi
fi

# execute commands passed to this container
exec "$@"

#EOF