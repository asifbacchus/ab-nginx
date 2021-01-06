#!/bin/sh

#
### ab-nginx entrypoint script
#

convertCase () {
    printf "%s" "$1" | tr "[:lower:]" "[:upper:]"
}

# convert environment variables to UPPERCASE for proper string comparison
ACCESS_LOG=$(convertCase "$ACCESS_LOG")
HSTS=$(convertCase "$HSTS")
TLS13_ONLY=$(convertCase "$TLS13_ONLY")

# export new environment variables
export ACCESS_LOG=$ACCESS_LOG
export HSTS=$HSTS
export TLS13_ONLY=$TLS13_ONLY

### update configuration files with environment variables
# update server name list
printf "\nUpdating server name list... "
sed -i -e "s%<SERVER_NAMES>%${SERVER_NAMES}%" /etc/nginx/server_names.conf
printf "done\n"

# update access log global preference
if [ "$ACCESS_LOG" = 'OFF' ]; then
    printf "Turning access log OFF... "
    sed -i -e "s%<ACCESS_LOG_SETTING>%off%" /etc/nginx/nginx.conf
    printf "done\n"
elif [ "$ACCESS_LOG" = 'ON' ]; then
    printf "Turning access log ON... "
    sed -i -e "s%<ACCESS_LOG_SETTING>%/var/log/nginx/access.log combined%" /etc/nginx/nginx.conf
    printf "done\n"
fi

# update HTTPS redirect port if SSL server test block exists
if [ -f "/etc/nginx/sites/note" ]; then
    printf "Updating port redirects... "
    sed -i -e "s%<HTTPS_PORT>%${HTTPS_PORT}%" /etc/nginx/sites/05-test_secured.*
    printf "done\n"
fi

# activate HSTS
if [ "$HSTS" = 'TRUE' ]; then
    printf "Activating HSTS configuration... "
    sed -i -e "s/^#add_header/add_header/" \
        /etc/nginx/ssl-config/moz*
    printf "done\n"
fi

# check whether TLS should be activated
if [ -f "/certs/fullchain.pem" ]; then
    # activate SSL configuration as appropriate and only if certs exist
    if [ "$TLS13_ONLY" = 'FALSE' ]; then
        if [ -f "/certs/fullchain.pem" ] && [ -f "/certs/privkey.pem" ] && [ -f "/certs/chain.pem" ] && [ -f "/certs/dhparam.pem" ]; then
            printf "Certificates found. Securing deployment using TLS 1.2\n"
            # activate shared SSL configuration file
            if [ -f "/etc/nginx/ssl-config/mozIntermediate_ssl.conf.disabled" ]; then
                mv /etc/nginx/ssl-config/mozIntermediate_ssl.conf.disabled \
                  /etc/nginx/ssl-config/mozIntermediate_ssl.conf
            fi
            if [ -f "/etc/nginx/ssl-config/mozModern_ssl.conf" ]; then
                mv /etc/nginx/ssl-config/mozModern_ssl.conf \
                  /etc/nginx/ssl-config/mozModern_ssl.conf.disabled
            fi

            # if using default setup, activate secured server block
            if [ -f "/etc/nginx/sites/note" ]; then
                if [ -f "/etc/nginx/sites/05-test_secured.conf.disabled" ]; then
                    mv /etc/nginx/sites/05-test_secured.conf.disabled \
                      /etc/nginx/sites/05-test_secured.conf
                fi
                if [ -f "/etc/nginx/sites/05-test_nonsecured.conf" ]; then
                    mv /etc/nginx/sites/05-test_nonsecured.conf \
                      /etc/nginx/sites/05-test_nonsecured.conf.disabled
                fi
            fi
        fi
    elif [ "$TLS13_ONLY" = 'TRUE' ]; then
        if [ -f "/certs/fullchain.pem" ] && [ -f "/certs/privkey.pem" ] && [ -f "/certs/chain.pem" ]; then
            printf "Certificates found. Securing deployment using TLS 1.3\n"
            # activate shared SSL configuration file
            if [ -f "/etc/nginx/ssl-config/mozModern_ssl.conf.disabled" ]; then
                mv /etc/nginx/ssl-config/mozModern_ssl.conf.disabled \
                  /etc/nginx/ssl-config/mozModern_ssl.conf
            fi
            if [ -f "/etc/nginx/ssl-config/mozIntermediate_ssl.conf" ]; then
                mv /etc/nginx/ssl-config/mozIntermediate_ssl.conf \
                  /etc/nginx/ssl-config/mozIntermediate_ssl.conf.disabled
            fi

            # if using default setup, activate secure server block
            if [ -f "/etc/nginx/sites/note" ]; then
                if [ -f "/etc/nginx/sites/05-test_secured.conf.disabled" ]; then
                    mv /etc/nginx/sites/05-test_secured.conf.disabled \
                      /etc/nginx/sites/05-test_secured.conf
                fi
                if [ -f "/etc/nginx/sites/05-test_nonsecured.conf" ]; then
                    mv /etc/nginx/sites/05-test_nonsecured.conf \
                      /etc/nginx/sites/05-test_nonsecured.conf.disabled
                fi
            fi
        fi
    fi
else
    # ensure SSL configurations are disabled
    for f in /etc/nginx/ssl-config/*; do mv "$f" "${f%%.*}.conf.disabled"; done
    # if using default setup, ensure secure server block disabled
    if [ -f "/etc/nginx/sites/note" ]; then
        if [ -f "/etc/nginx/sites/05-test_secured.conf" ]; then
            mv /etc/nginx/sites/05-test_secured.conf /etc/nginx/sites/05-test_secured.conf.disabled
        fi
        if [ -f "/etc/nginx/sites/05-test_nonsecured.conf.disabled" ]; then
            mv /etc/nginx/sites/05-test_nonsecured.conf.disabled /etc/nginx/sites/05-test_nonsecured.conf
        fi
    fi
fi


# execute commands passed to this container
printf "\nSetup complete...Container ready...\n"
exec "$@"

#EOF