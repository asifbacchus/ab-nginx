#!/bin/sh

#
# generate checksums from provided path suitable for use by 'update.sh'
#

# check for missing path to helper files, otherwise strip trailing slash
if [ -z "$1" ]; then
    printf "\nPlease supply path to helper files. Exiting.\n\n"
    exit 1
fi
srcDir="${1%/}"

# verify path exists and is accessible
if ! [ -d "$srcDir" ]; then
    printf "\nUnable to find or read supplied path to helper files. Exiting.\n\n"
    exit 1
fi

# generate checksum file
\rm -f "${srcDir}/checksums.sha256"
find "${srcDir}/" -type f -exec sha256sum {} + >>"${srcDir}/checksums.sha256"
sed -i "s+$srcDir/++g" "${srcDir}/checksums.sha256"

# exit gracefully
exit 0

#EOF
