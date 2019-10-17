#!/bin/sh

#
### start openldap container using params file variables
#

# text formatting presets
cyan=$(tput setaf 6)
err=$(tput bold)$(tput setaf 1)
magenta=$(tput setaf 5)
norm=$(tput sgr0)
yellow=$(tput setaf 3)


### parameter defaults
container_name="ab-nginx"
shell=false


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
    printf "Note: This container removes itself upon exit.\n\n"
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
if [ ! -f "./ab-nginx.params" ]; then
    printf "${err}\nCannot find 'ab-nginx.params' file in the same directory as this script. Exiting.\n${norm}"
    exit 3
fi

# check for certs if using SSL
if [ "$SSL_CERT" ]; then
    if [ ! -f "$SSL_CERT" ]; then
        printf "${err}\nCannot find specified SSL certificate file. Exiting.${norm}\n"
        exit 5
    fi
    if [ ! -f "$SSL_KEY" ]; then
        printf "${err}\nCannot find specified SSL private key file. Exiting.${norm}\n"
        exit 5
    fi
    if [ ! -f "$SSL_CHAIN" ]; then
        printf "${err}\nCannot find specified SSL certificate chain file. Exiting.${norm}\n"
        exit 5
    fi
fi

# check for DHparam if using TLS1.2
if [ "$TLS13_ONLY" = FALSE ]; then
    if [ -z "$DH" ]; then
        printf "${err}\nA DHparam file must be specified when using TLS 1.2. Exiting.${norm}\n"
        exit 5
    elif [ -f "$DH" ]; then
        printf "${err}\nCannot find specified DHparam file. Exiting.${norm}\n"
        exit 5
    fi
fi


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

# read .params file
. ./ab-openldap.params


# run without TLS
if [ -z "$SSL_CERT" ]; then    
    if [ $shell = true ]; then
        # exec shell
        printf "${cyan}\nRunning SHELL on %s...${norm}\n" "$container_name"
        docker run --rm -it --name ${container_name} --env-file ab-nginx.params -p 80:80 ab-nginx:testing /bin/sh
    else
        # exec normally
        printf "${cyan}\nRunning NGINX on %s...${norm}\n" "$container_name"
        docker run --rm -d --name ${container_name} --env-file ab-nginx.params -p 80:80 ab-nginx:testing
    fi
# run with TLS1.2
elif [ "$SSL_CERT" ] && [ "$TLS13_ONLY" = FALSE ]; then
    if [ $shell = true ]; then
        # exec shell
        printf "${cyan}\nRunning SHELL on %s (TLS 1.2)...${norm}\n" "$container_name"
        docker run --rm -it --name ${container_name} \
            --env-file ab-nginx.params \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -v "$DH":/certs/dhparam.pem:ro \
            -p 80:80 -p 443:443 \
            ab-nginx:testing /bin/sh
    else
        # exec normally
        printf "${cyan}\nRunning OPENLDAP on %s (TLS 1.2)...${norm}\n" "$container_name"
        docker run --rm -d --name ${container_name} \
            --env-file ab-nginx.params \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -v "$DH":/certs/dhparam.pem:ro \
            -p 80:80 -p 443:443 \
            ab-nginx:testing
    fi
# run with TLS1.3
elif [ "$SSL_CERT" ] && [ "$TLS13_ONLY" = TRUE ]; then
    if [ $shell = true ]; then
        # exec shell
        printf "${cyan}\nRunning SHELL on %s (TLS 1.3)...${norm}\n" "$container_name"
        docker run --rm -it --name ${container_name} \
            --env-file ab-nginx.params \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -p 80:80 -p 443:443 \
            ab-nginx:testing /bin/sh
    else
        # exec normally
        printf "${cyan}\nRunning OPENLDAP on %s (TLS 1.3)...${norm}\n" "$container_name"
        docker run --rm -d --name ${container_name} \
            --env-file ab-nginx.params \
            -v "$SSL_CERT":/certs/fullchain.pem:ro \
            -v "$SSL_KEY":/certs/privkey.pem:ro \
            -v "$SSL_CHAIN":/certs/chain.pem:ro \
            -p 80:80 -p 443:443 \
            ab-nginx:testing
    fi
fi


### exit gracefully
exit 0