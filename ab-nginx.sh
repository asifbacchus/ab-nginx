#!/bin/sh

#
### start ab-nginx container using params file variables
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

checkExist() {
  if [ "$1" = 'file' ]; then
    if [ ! -f "$2" ]; then
      printf "%s\nCannot find file: '$2'. Exiting.\n%s" "$err" "$norm"
      exit 3
    fi
  elif [ "$1" = 'dir' ]; then
    if [ ! -d "$2" ]; then
      printf "%s\nCannot find directory: '$2'. Exiting.\n$%s" "$err" "$norm"
      exit 3
    fi
  fi
  return 0
}

scriptHelp() {
  printf "\n%s%1000s\n" "$magenta" | tr " " "-" | cut -c -$width
  printf "%s" "$norm"
  textblock "This is a simple helper script so you can avoid lengthy typing when working with the nginx container. The script reads the contents of 'ab-nginx.params' and constructs various 'docker run' commands based on that file. The biggest time-saver is working with certificates. If they are specified in the params file, the script will automatically bind-mount them so nginx serves content via SSL by default."
  newline
  textblock "If you run the script with no parameters, it will execute the container 'normally': Run in detached mode with nginx automatically launched and logging to stdout.  If you specified certificates, nginx will serve over SSL by default."
  newline
  textblock "Note: Containers (except shell) are always set to restart 'unless-stopped'. You must remove them manually if desired."
  printf "%s" "$magenta"
  newline
  textblock "The script has the following parameters:"
  textblockParam 'parameter in cyan' 'default in yellow'
  newline
  textblockParam '-n|--name' 'ab-nginx'
  textblock "Change the name of the container. This is cosmetic and does not affect operation in any way."
  newline
  textblockParam '-s|--shell' 'off: run in detached mode'
  textblock "Enter the container using an interactive POSIX shell. This happens after startup operations but *before* nginx is actually started. This is a great way to see configuration changes possibly stopping nginx from starting normally."
  printf "%s" "$yellow"
  newline
  textblock "More information can be found at: https://git.asifbacchus.app/ab-docker/ab-nginx/wiki"
  printf "%s%1000s\n" "$magenta" | tr " " "-" | cut -c -$width
  exit 0
}

newline() {
  printf "\n"
}

textblock() {
  printf "%s\n" "$1" | fold -w "$width" -s
}

textblockParam() {
  if [ -z "$2" ]; then
    # no default
    printf "%s%s%s\n" "$cyan" "$1" "$norm"
  else
    # default param provided
    printf "%s%s %s(%s)%s\n" "$cyan" "$1" "$yellow" "$2" "$norm"
  fi
}

### pre-requisite checks

# is user root or in the docker group?
if [ ! "$(id -u)" -eq 0 ]; then
  if ! id -Gn | grep docker >/dev/null; then
    printf "%s\nYou must either be root or in the 'docker' group to run this script since you must be able to actually start the container! Exiting.\n$%s" "$err" "$norm"
    exit 2
  fi
fi

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

# check for DHparam if using TLS1.2
if [ "$SSL_CERT" ] && [ "$TLS13_ONLY" = 'FALSE' ]; then
  if [ -z "$DH" ]; then
    printf "%s\nA DHparam file must be specified when using TLS 1.2. Exiting.%s\n" "$err" "$norm"
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
if [ "$SNIPPETS_DIR" ]; then
  vmount="$vmount -v $SNIPPETS_DIR:/etc/nginx/snippets"
fi
if [ "$WEBROOT_DIR" ]; then
  vmount="$vmount -v $WEBROOT_DIR:/usr/share/nginx/html"
fi
# trim leading whitespace
vmount=${vmount##[[:space:]]}

# handle null HOSTNAMES
if [ -z "$HOSTNAMES" ]; then HOSTNAMES="_"; fi

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
    shell=true
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
  *)
    printf "%s\nUnknown option: %s\n" "$err" "$1"
    printf "Use '--help' for valid options.\n\n%s" "$norm"
    exit 1
    ;;
  esac
  shift
done

# create network if it doesn't already exist
docker network inspect ${NETWORK} >/dev/null 2>&1 ||
  docker network create \
    --attachable \
    --driver=bridge \
    --subnet=${SUBNET} \
    ${NETWORK}

# run without TLS
if [ -z "$SSL_CERT" ]; then
  if [ $shell = 'true' ]; then
    # exec shell
    printf "%s\nRunning SHELL on %s...%s\n" "$cyan" "$container_name" "$norm"
    docker run --rm -it --name "${container_name}" \
      --env-file ab-nginx.params \
      -e SERVER_NAMES="$HOSTNAMES" \
      $vmount \
      --network=${NETWORK} \
      -p ${HTTP_PORT}:80 \
      docker.asifbacchus.app/nginx/ab-nginx:latest /bin/sh
  else
    # exec normally
    printf "%s\nRunning NGINX on %s...%s\n" "$cyan" "$container_name" "$norm"
    docker run -d --name "${container_name}" \
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
    printf "%s\nRunning SHELL on %s (TLS 1.2)...%s\n" "$cyan" "$container_name" "$norm"
    docker run --rm -it --name "${container_name}" \
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
    printf "%s\nRunning NGINX on %s (TLS 1.2)...%s\n" "$cyan" "$container_name" "$norm"
    docker run -d --name "${container_name}" \
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
    printf "%s\nRunning SHELL on %s (TLS 1.3)...%s\n" "$cyan" "$container_name" "$norm"
    docker run --rm -it --name "${container_name}" \
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
    printf "%s\nRunning NGINX on %s (TLS 1.3)...%s\n" "$cyan" "$container_name" "$norm"
    docker run -d --name "${container_name}" \
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