#!/bin/sh

#
### start ab-nginx container using params file variables
#

# text formatting presets
cyan=$(tput setaf 6)
err=$(tput bold)$(tput setaf 1)
magenta=$(tput setaf 5)
norm=$(tput sgr0)
yellow=$(tput setaf 3)


### parameter defaults
shell=false
container_name="ab-nginx"
NETWORK='nginx_network'
SUBNET='172.31.254.0/24'
HTTP_PORT=80
HTTPS_PORT=443
unset CONFIG_DIR
unset SERVERS_DIR
unset WEBROOT_DIR
unset vmount


### functions

checkExist () {
    if [ "$1" = 'file' ]; then
        if [ ! -f "$2" ]; then
            printf "${err}\nCannot find file: '$2'. Exiting.\n${norm}"
            exit 3
        fi
    elif [ "$1" = 'dir' ]; then
        if [ ! -d "$2" ]; then
            printf "${err}\nCannot find directory: '$2'. Exiting.\n${norm}"
            exit 3
        fi
    fi
    return 0
}

scriptHelp () {
    printf "\n${magenta}%80s\n" | tr " " "-"
    printf "${norm}This is a simple helper script so you can avoid lengthy typing when working\n"
    printf "with the nginx container.  The script reads the contents of 'ab-nginx.params'\n"
    printf "and constructs various 'docker run' commands based on that file.  The biggest\n"
    printf "timesaver is working with certificates.  If they are specified in params file,\n"
    printf "the script will automatically bind-mount them so nginx serves content via SSL\n"
    printf "by default.\n\n"
    printf "If you run the script with no parameters, it will execute the container\n"
    printf "'normally':  Run in detached mode with nginx automatically launched and\n"
    printf "logging to stdout.  If you specified certificates, nginx will serve over SSL\n"
    printf "by default.\n"
    printf "Note: Containers (except shell) are always set to restart 'unless-stopped'. You\n"
    printf "must remove them manually if desired.\n\n"
    printf "${magenta}The script has the following parameters:\n"
    printf "${cyan}(parameter in cyan) ${yellow}(default in yellow)${norm}\n\n"
    printf "${cyan}-n|--name${norm}\n"
    printf "Change the name of the container. This is cosmetic and does not affect\n"
    printf "operation in any way.\n"
    printf "${yellow}(ab-nginx)${norm}\n\n"
    printf "${cyan}-s|--shell${norm}\n"
    printf "Enter the container using an interactive POSIX shell.  This happens after\n"
    printf "startup operations but *before* nginx is actually started.  This is a great way\n"
    printf "to see configuration changes possibly stopping nginx from starting normally.\n"
    printf "${yellow}(off: run in detached mode)${norm}\n\n"
    printf "${yellow}More information can be found at:\n"
    printf "https://git.asifbacchus.app/ab-docker/ab-nginx/wiki\n"
    printf "${magenta}%80s\n\n" | tr " " "-"
    exit 0
}


### pre-requisite checks

# is user root or in the docker group?
if [ ! "$( id -u )" -eq 0 ]; then
    if ! id -Gn | grep docker > /dev/null; then
        printf "${err}\nYou must either be root or in the 'docker' group to run this script since you must be able to actually start the container! Exiting.\n${norm}"
        exit 2
    fi
fi

# does the params file exist?
checkExist 'file' './ab-nginx.params'

# read .params file
. ./ab-nginx.params

# check for certs if using SSL
checkExist 'file' "$SSL_CERT"
checkExist 'file' "$SSL_KEY"
checkExist 'file' "$SSL_CHAIN"

# check for DHparam if using TLS1.2
if [ "$TLS13_ONLY" = 'FALSE' ]; then
    if [ -z "$DH" ]; then
        printf "${err}\nA DHparam file must be specified when using TLS 1.2. Exiting.${norm}\n"
        exit 5
    else
        checkExist 'file' "$DH"
    fi
fi

# check if specified config directory exists
if [ "$CONFIG_DIR" ]; then
    checkExist 'dir' "$CONFIG_DIR"
fi

# check if specified server-block directory exists
if [ "$SERVERS_DIR" ]; then
    checkExist 'dir' "$SERVERS_DIR"
fi

# check if specified webroot directory exists
if [ "$WEBROOT_DIR" ]; then
    checkExist 'dir' "$WEBROOT_DIR"
fi

# set up volume mounts
if [ "$CONFIG_DIR" ]; then
    vmount="$vmount -v $CONFIG_DIR:/etc/nginx/config"
fi
if [ "$SERVERS_DIR" ]; then
    vmount="$vmount -v $SERVERS_DIR:/etc/nginx/sites"
fi
if [ "$WEBROOT_DIR" ]; then
    vmount="$vmount -v $WEBROOT_DIR:/usr/share/nginx/html"
fi
# trim leading whitespace
vmount=${vmount##[[:space:]]}
echo "$vmount"


# process startup parameters
while [ $# -gt 0 ]; do
    case "$1" in
        -h|-\?|--help)
            # display help
            scriptHelp
            exit 0
            ;;
        -s|--shell)
            # start shell instead of default CMD
            shell=true
            ;;
        -n|--name)
            # container name
            if [ -z "$2" ]; then
                printf "${err}\nNo container name specified. Exiting.\n${norm}"
                exit 1
            fi
            container_name="$2"
            shift
            ;;
        *)
            printf "${err}\nUnknown option: %s\n" "$1"
            printf "Use '--help' for valid options.\n\n${norm}"
            exit 1
            ;;
    esac
    shift
done

# create network if it doesn't already exist
docker network inspect ${NETWORK} > /dev/null 2>&1 || \
    docker network create \
        --attachable \
        --driver=bridge \
        --subnet=${SUBNET} \
        ${NETWORK}


# run without TLS
if [ -z "$SSL_CERT" ]; then    
    if [ $shell = 'true' ]; then
        # exec shell
        printf "${cyan}\nRunning SHELL on %s...${norm}\n" "$container_name"
        docker run --rm -it --name ${container_name} \
            --env-file ab-nginx.params \
            -e SERVER_NAMES="$HOSTNAMES" \
            $vmount \
            --network=${NETWORK} \
            -p ${HTTP_PORT}:80 \
            docker.asifbacchus.app/nginx/ab-nginx:latest /bin/sh
    else
        # exec normally
        printf "${cyan}\nRunning NGINX on %s...${norm}\n" "$container_name"
        docker run -d --name ${container_name} \
        --env-file ab-nginx.params \
        -e SERVER_NAMES="$HOSTNAMES" \
        $vmount \
        --network=${NETWORK} \
        -p ${HTTP_PORT}:80 \
        --restart unless-stopped \
        docker.asifbacchus.app/nginx/ab-nginx:latest
    fi
# run with TLS1.2
elif [ "$SSL_CERT" ] && [ "$TLS13_ONLY" = 'FALSE' ]; then
    if [ $shell = 'true' ]; then
        # exec shell
        printf "${cyan}\nRunning SHELL on %s (TLS 1.2)...${norm}\n" "$container_name"
        docker run --rm -it --name ${container_name} \
            --env-file ab-nginx.params \
            -e SERVER_NAMES="$HOSTNAMES" \
            $vmount \
            --network=${NETWORK} \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -v "$DH":/certs/dhparam.pem:ro \
            -p ${HTTP_PORT}:80 -p ${HTTPS_PORT}:443 \
            docker.asifbacchus.app/nginx/ab-nginx:latest /bin/sh
    else
        # exec normally
        printf "${cyan}\nRunning NGINX on %s (TLS 1.2)...${norm}\n" "$container_name"
        docker run -d --name ${container_name} \
            --env-file ab-nginx.params \
            -e SERVER_NAMES="$HOSTNAMES" \
            $vmount \
            --network=${NETWORK} \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -v "$DH":/certs/dhparam.pem:ro \
            -p ${HTTP_PORT}:80 -p ${HTTPS_PORT}:443 \
            --restart unless-stopped \
            docker.asifbacchus.app/nginx/ab-nginx:latest
    fi
# run with TLS1.3
elif [ "$SSL_CERT" ] && [ "$TLS13_ONLY" = 'TRUE' ]; then
    if [ $shell = 'true' ]; then
        # exec shell
        printf "${cyan}\nRunning SHELL on %s (TLS 1.3)...${norm}\n" "$container_name"
        docker run --rm -it --name ${container_name} \
            --env-file ab-nginx.params \
            -e SERVER_NAMES="$HOSTNAMES" \
            $vmount \
            --network=${NETWORK} \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -p ${HTTP_PORT}:80 -p ${HTTPS_PORT}:443 \
            docker.asifbacchus.app/nginx/ab-nginx:latest /bin/sh
    else
        # exec normally
        printf "${cyan}\nRunning NGINX on %s (TLS 1.3)...${norm}\n" "$container_name"
        docker run -d --name ${container_name} \
            --env-file ab-nginx.params \
            -e SERVER_NAMES="$HOSTNAMES" \
            $vmount \
            --network=${NETWORK} \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -p ${HTTP_PORT}:80 -p ${HTTPS_PORT}:443 \
            --restart unless-stopped \
            docker.asifbacchus.app/nginx/ab-nginx:latest
    fi
fi


### exit gracefully
exit 0
