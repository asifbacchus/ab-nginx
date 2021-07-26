#!/bin/sh

#
# generate a self-signed certificate
#

# check for null hostname
if [ -z "$1" ]; then
    printf "\nPlease supply a hostname for the generated certificate as a parameter to this script. Exiting.\n\n"
    exit 1
fi

# update openssl configuration file
sed -e "s/{CERT_HOSTNAME}/$1/" /etc/selfsigned.cnf > /tmp/selfsigned.cnf

printf "\nGenerating self-signed certificate for '%s':\n" "$1"

# create placeholder files to set permissions
if ! touch /certs/fullchain.pem && chmod 644 /certs/fullchain.pem; then
    printf "\nUnable to write to '/certs', is it mounted writable by this container?\n\n"
    exit 2
fi
touch /certs/privkey.pem && chmod 640 /certs/privkey.pem

# generate certificate
if ! openssl req -new -x509 -days 365 -nodes -out /certs/fullchain.pem -keyout /certs/privkey.pem -config /tmp/selfsigned.cnf; then
    printf "\nUnable to generate certificate. Is the '/certs' directory writable by this container?\n\n"
    exit 3
fi
\cp /certs/fullchain.pem /certs/chain.pem

# print user notification
printf "\n\nA self-signed certificate has been generated and saved in the location mounted to '/certs' in this container.\n"
printf "The certificate and private key are PEM formatted with names 'fullchain.pem' and 'privkey.pem', respectively.\n"
printf "Remember to import 'fullchain.pem' to the trusted store on any client machines or you will get warnings.\n\n"

# exit gracefully
exit 0


#
# exit codes
# 0:    normal exit, no errors
# 1:    invalid or missing parameters
# 2:    unable to write to certs directory
# 3:    unable to generate certificate

#EOF
