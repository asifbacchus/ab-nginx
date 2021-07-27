#!/bin/sh

#
# start ab-nginx container using params file variables
#

# TODO: add error trapping on docker run statements

#
# text formatting presets
if command -v tput >/dev/null; then
    cyan=$(tput bold)$(tput setaf 6)
    err=$(tput bold)$(tput setaf 1)
    magenta=$(tput sgr0)$(tput setaf 5)
    norm=$(tput sgr0)
    yellow=$(tput sgr0)$(tput setaf 3)
    width=$(tput cols)
else
    cyan=''
    err=''
    magenta=''
    norm=''
    yellow=''
    width=80
fi

#
# parameter defaults
doShell=false
doStatus=false
doStop=false
removeStopped=false
container_name="ab-nginx"
NETWORK='nginx_network'
SUBNET='172.31.254.0/24'
HTTP_PORT=80
HTTPS_PORT=443
CONFIG_DIR=""
SERVERS_DIR=""
WEBROOT_DIR=""
volumeMounts=""
stopErr=0
removeErr=0

#
# functions
checkExist() {
    if [ "$1" = 'file' ]; then
        if [ ! -f "$2" ]; then
            printf "%s\nCannot find file: '$2'. Exiting.\n%s" "$err" "$norm"
            exit 1
        fi
    elif [ "$1" = 'dir' ]; then
        if [ ! -d "$2" ]; then
            printf "%s\nCannot find directory: '$2'. Exiting.\n$%s" "$err" "$norm"
            exit 1
        fi
    fi
    return 0
}

scriptHelp() {
    # header and description
    printf "\n%s" "$magenta"
    printf '%.0s-' $(seq "$width")
    printf "\n%s" "$norm"
    textBlock "This is a simple helper script so you can avoid typing lengthy commands when working with the ab-nginx container."
    textBlock "The script reads the contents of 'ab-nginx.params' and constructs various 'docker run' commands based on that file. The biggest time-saver is working with certificates. If they are specified in the params file, the script will automatically bind-mount them so nginx serves content via SSL by default."
    newline

    # explanatory text
    textBlock "If you run the script with no parameters, it will execute the container 'normally': Run in detached mode with nginx automatically launched. If you specified certificates, nginx will serve over SSL by default."
    textBlock "Note: Containers (except shell) are always set to restart 'unless-stopped'. You must remove them manually if desired."
    printf "%s" "$magenta"
    newline

    # parameters
    textBlock "The script has the following (optional) parameters:"
    textBlockParam 'parameter in cyan' 'default in yellow'
    newline
    textBlockParam '-n|--name' 'ab-nginx'
    textBlock "Set the name of the container, otherwise the default will be used."
    newline
    textBlockParam '-s|--shell' 'off: run in detached mode'
    textBlock "Enter the container using an interactive ASH/BusyBox shell. This happens after startup operations but *before* nginx is actually started. This is a great way to see configuration changes possibly stopping nginx from starting normally."
    newline
    textBlockParam '--status'
    textBlock "Run a search for all AB-NGINX containers and display their name and status."
    newline
    textBlockParam '--stop'
    textBlock "Stops the container specified by the '--name' parameter or with the default name 'ab-nginx'."
    newline
    textBlockParam '--remove | --stop-remove'
    textBlock "Stops and removes the container specified by the '--name' parameter or with the default name 'ab-nginx'."

    # footer
    newline
    printf "%s" "$yellow"
    textBlock"More information can be found at: https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki"
    printf "\n%s" "$magenta"
    printf '%.0s-' $(seq "$width")
    printf "\n%s" "$norm"
    exit 0
}

newline() {
    printf "\n"
}

textBlock() {
    printf "%s\n" "$1" | fold -w "$width" -s
}

textBlockParam() {
    if [ -z "$2" ]; then
        # no default
        printf "%s%s%s\n" "$cyan" "$1" "$norm"
    else
        # default param provided
        printf "%s%s %s(%s)%s\n" "$cyan" "$1" "$yellow" "$2" "$norm"
    fi
}

#
# pre-requisite checks

# is docker installed?
if ! command -v docker >/dev/null; then
    printf "%s\nCannot find docker... is it installed?\n%s" "$err" "$norm"
    exit 2
fi

# is user root or in the docker group?
if [ ! "$(id -u)" -eq 0 ]; then
    if ! id -Gn | grep docker >/dev/null; then
        printf "%s\nYou must either be root or in the 'docker' group to run this script since you must be able to actually start the container! Exiting.\n$%s" "$err" "$norm"
        exit 3
    fi
fi

#
# process startup parameters
while [ $# -gt 0 ]; do
    case "$1" in
    -h | -\? | --help)
        # display help
        scriptHelp
        exit 0
        ;;
    -s | --shell)
        # start shell instead of default CMD
        doShell=true
        ;;
    -n | --name)
        # container name
        if [ -z "$2" ]; then
            printf "%s\nNo container name specified. Exiting.\n%s" "$err" "$norm"
            exit 1
        fi
        container_name="$2"
        shift
        ;;
    --status)
        # find containers and check their status
        doStatus=true
        ;;
    --stop)
        # stop named container
        doStop=true
        ;;
    --remove | --stop-remove)
        # stop and remove named container
        doStop=true
        removeStopped=true
        ;;
    *)
        printf "%s\nUnknown option: %s\n" "$err" "$1"
        printf "Use '--help' for valid options.\n\n%s" "$norm"
        exit 1
        ;;
    esac
    shift
done

#
# status check
if [ "$doStatus" = "true" ]; then
    printf "\nFound the following AB-NGINX containers:\n"
    docker ps -a --filter "label=dev.asifbacchus.docker.internalName=ab-nginx"
    printf "\n"
    exit 0
fi

#
# stop container
if [ "$doStop" = "true" ]; then
    printf "\nStopping container '%s'... " "$container_name"

    # ensure container exists
    if ! docker inspect "$container_name" >/dev/null 2>&1; then
        printf "[ERROR]: No container with that name found.\n\n"
        exit 11
    fi

    # stop and/or remove container
    if ! docker stop "$container_name" >/dev/null 2>&1; then stopErr=1; fi
    if [ "$removeStopped" = "true" ] && [ "$stopErr" -eq 0 ]; then
        if ! docker rm "$container_name" >/dev/null 2>&1; then removeErr=1; fi
    fi

    # update status message
    if [ "$stopErr" -eq 1 ]; then
        printf "[ERROR]: Unable to stop container. Please try removing it manually.\n\n"
        exit 12
    fi
    if [ "$removeErr" -eq 1 ]; then
        printf "[STOPPED]\n"
        printf "[ERROR]: Unable to remove container. Please try removing it manually.\n\n"
        exit 13
    fi
    if [ "$removeStopped" = "true" ]; then
        printf "[REMOVED]\n\n"
    else
        printf "[STOPPED]\n\n"
    fi
    exit 0
fi

#
# run container

# does the params file exist?
checkExist 'file' './ab-nginx.params'

# read .params file
. "./ab-nginx.params"

# fix case of TLS13_ONLY var
if [ "$TLS13_ONLY" ]; then
    TLS13_ONLY=$(printf "%s" "$TLS13_ONLY" | tr "[:lower:]" "[:upper:]")
fi

# check for certs if using SSL
if [ "$SSL_CERT" ]; then checkExist 'file' "$SSL_CERT"; fi
if [ "$SSL_KEY" ]; then checkExist 'file' "$SSL_KEY"; fi
if [ "$SSL_CHAIN" ]; then checkExist 'file' "$SSL_CHAIN"; fi

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
    volumeMounts="${volumeMounts} -v $CONFIG_DIR:/etc/nginx/config"
fi
if [ "$SERVERS_DIR" ]; then
    volumeMounts="${volumeMounts} -v $SERVERS_DIR:/etc/nginx/sites"
fi
if [ "$SNIPPETS_DIR" ]; then
    volumeMounts="${volumeMounts} -v $SNIPPETS_DIR:/etc/nginx/snippets"
fi
if [ "$WEBROOT_DIR" ]; then
    volumeMounts="${volumeMounts} -v $WEBROOT_DIR:/usr/share/nginx/html"
fi
# trim leading whitespace
volumeMounts=${volumeMounts##[[:space:]]}

# handle null HOSTNAMES
if [ -z "$HOSTNAMES" ]; then HOSTNAMES="_"; fi

# create network if it doesn't already exist
docker network inspect ${NETWORK} >/dev/null 2>&1 ||
    docker network create \
        --attachable \
        --driver=bridge \
        --subnet=${SUBNET} \
        ${NETWORK}

# run without TLS
if [ -z "$SSL_CERT" ]; then
    if [ "$doShell" = 'true' ]; then
        # exec shell
        printf "%s\nRunning SHELL on %s...%s\n" "$cyan" "$container_name" "$norm"
        # shellcheck disable=SC2086
        docker run --rm -it --name "${container_name}" \
            --env-file ab-nginx.params \
            --user="${NGINX_UID:-8080}:${NGINX_GID:-8080}" \
            -e SERVER_NAMES="$HOSTNAMES" \
            ${volumeMounts} \
            --network=${NETWORK} \
            -p ${HTTP_PORT}:80 \
            docker.asifbacchus.dev/nginx/ab-nginx:latest /bin/sh
    else
        # exec normally
        printf "%s\nRunning NGINX on %s...%s\n" "$cyan" "$container_name" "$norm"
        # shellcheck disable=SC2086
        docker run -d --name "${container_name}" \
            --env-file ab-nginx.params \
            --user="${NGINX_UID:-8080}:${NGINX_GID:-8080}" \
            -e SERVER_NAMES="$HOSTNAMES" \
            ${volumeMounts} \
            --network=${NETWORK} \
            -p ${HTTP_PORT}:80 \
            --restart unless-stopped \
            docker.asifbacchus.dev/nginx/ab-nginx:${TAG:-latest}
    fi
# run with TLS
else
    if [ "$doShell" = 'true' ]; then
        if [ "$TLS13_ONLY" = 'FALSE' ]; then
            printf "%s\nRunning SHELL on %s (TLS 1.2)...%s\n" "$cyan" "$container_name" "$norm"
        else
            printf "%s\nRunning SHELL on %s (TLS 1.3)...%s\n" "$cyan" "$container_name" "$norm"
        fi
        # shellcheck disable=SC2086
        docker run --rm -it --name "${container_name}" \
            --env-file ab-nginx.params \
            --user="${NGINX_UID:-8080}:${NGINX_GID:-8080}" \
            -e SERVER_NAMES="$HOSTNAMES" \
            ${volumeMounts} \
            --network=${NETWORK} \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -p ${HTTP_PORT}:80 -p ${HTTPS_PORT}:443 \
            docker.asifbacchus.dev/nginx/ab-nginx:${TAG:-latest} /bin/sh
    else
        if [ "$TLS13_ONLY" = 'FALSE' ]; then
            printf "%s\nRunning NGINX on %s (TLS 1.2)...%s\n" "$cyan" "$container_name" "$norm"
        else
            printf "%s\nRunning NGINX on %s (TLS 1.3)...%s\n" "$cyan" "$container_name" "$norm"
        fi
        # shellcheck disable=SC2086
        docker run -d --name "${container_name}" \
            --env-file ab-nginx.params \
            --user="${NGINX_UID:-8080}:${NGINX_GID:-8080}" \
            -e SERVER_NAMES="$HOSTNAMES" \
            ${volumeMounts} \
            --network=${NETWORK} \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -p ${HTTP_PORT}:80 -p ${HTTPS_PORT}:443 \
            --restart unless-stopped \
            docker.asifbacchus.dev/nginx/ab-nginx:${TAG:-latest}
    fi
fi

#
# exit gracefully
exit 0

#
# exit return codes
# 0:        normal exit, no errors
# 1:        missing or invalid parameter
# 2:        cannot find docker
# 3:        incorrect permissions to access docker
# 1x:       operation errors
#   11      no container found with specified name
#   12      unable to stop container
#   13      unable to remove container

#EOF
