#!/bin/sh

#
# update script for ab-nginx container and utility scripts
#   version 2.1.0
#   script by Asif Bacchus
#

#
# functions
errMsg() {
    printf "\n%s%s%s\n\n" "$err" "$1" "$norm"
    [ -n "$2" ] && exit "$2" || exit 1
}

errNotify() {
    printf "%s[ERROR]%s\n" "$err" "$norm"
}

okMsg() {
    printf "%s%s%s\n\n" "$ok" "$1" "$norm"
}

okNotify() {
    printf "%s[OK]%s\n" "$ok" "$norm"
}

scriptHelp() {
    textNewline
    textBlock "Update ${containerName} container and helper script files"
    textBlock "${bold}Usage: ${localScriptName} [parameters]${norm}"
    textNewline
    textBlock "If run with no parameters, the script will update both the container and the helper script files, including this update script."
    textBlockHeader " parameters "
    textBlockParam "-h|-?|--help" "Display this help screen."
    textBlockParam "-c|--container|--container-only" "Update the docker container only."
    textBlockParam "-s|--scripts|--scripts-only" "Update the helper scripts (including this update script) only."
    textNewline
    exit 0
}

textBlock() {
    printf "%s\n" "$1" | fold -w "$width" -s
}

textBlockHeader() {
    printf "\n%s***%s***%s\n" "$header" "$1" "$norm"
}

textBlockParam() {
    printf "%s%-35s%s%s\n" "$info" "$1" "$2" "$norm"
}

textNewline() {
    printf "\n"
}

#
# text formatting presets
if command -v tput >/dev/null 2>&1; then
    bold=$(tput bold)
    err=$(tput bold)$(tput setaf 1)
    info=$(tput bold)$(tput setaf 6)
    header=$(tput bold)$(tput setaf 5)
    norm=$(tput sgr0)
    ok=$(tput sgr0)$(tput setaf 2)
    warn=$(tput bold)$(tput setaf 3)
    width=$(tput cols)
else
    bold=''
    err=''
    info=''
    header=''
    norm=''
    ok=''
    warn=''
    width=80
fi

#
# pre-requisites
# check if wget is installed
if ! command -v wget >/dev/null 2>&1; then
    errMsg "Sorry, this script requires that 'wget' is installed in order to download updates. Exiting."
fi

# zero counters
updatesAvailable=0
downloadFailed=0
downloadSuccess=0
updateFailed=0
updateSuccess=0

# reference constants
dockerNamespace='nginx'
containerName='ab-nginx'
containerUpdatePath="docker.asifbacchus.dev/$dockerNamespace/$containerName:latest"
server="https://asifbacchus.dev/public/docker/$dockerNamespace/$containerName/"
checksumFilename='checksums.sha256'

# operation triggers
doDockerUpdate=1
doScriptUpdate=1

# files to update
localScriptName="$(basename "$0")"
repoScriptName='update.sh'

#
# process startup parameters
while [ $# -gt 0 ]; do
    case "$1" in
    -h | -\? | --help)
        # display inline help
        scriptHelp
        ;;
    -s | --scripts | --scripts-only)
        # update scripts only, skip docker container update
        doDockerUpdate=0
        ;;
    -c | --container | --container-only)
        # update docker container only, skip script update
        doScriptUpdate=0
        ;;
    *)
        printf "%s\nUnknown option: %s\n" "$err" "$1"
        printf "%sUse '--help' for valid options%s\n\n" "$info" "$norm"
        exit 1
        ;;
    esac
    shift
done

#
# update container
if [ "$doDockerUpdate" -eq 1 ]; then
    # check if docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        errMsg "Sorry, it appears that docker is not installed on this machine! Exiting." 2
    fi

    # is user root or in the docker group?
    if [ ! "$(id -u)" -eq 0 ]; then
        if ! id -Gn | grep docker >/dev/null; then
            errMsg "You must either be root or in the 'docker' group to pull container updates." 2
        fi
    fi

    printf "%s\n*** Updating %s container ***\n\n%s" "$info" "$containerName" "$norm"
    if ! docker pull "$containerUpdatePath"; then
        errMsg "There was an error updating the container. Try again later." 31
    else
        okMsg "Container updated!"
    fi
fi

#
# update scripts
if [ "$doScriptUpdate" -eq 1 ]; then
    printf "%s*** Updating %s service scripts ***%s\n" "$info" "$containerName" "$norm"

    ## download latest checksums
    printf "Getting latest checksums... "
    if ! wget --quiet --tries=3 --timeout=10 -N "${server}${checksumFilename}"; then
        errNotify
        errMsg "Unable to download checksums. Try again later." 41
    else
        okNotify
    fi

    ## check for updates to this script
    printf "Checking for updates to this script... "
    repoScriptChecksum=$(grep "$repoScriptName" "$checksumFilename" | grep -o '^\S*')
    localScriptChecksum=$(sha256sum "$localScriptName" | grep -o '^\S*')
    if [ "$localScriptChecksum" = "$repoScriptChecksum" ]; then
        printf "[NONE]\n"
    else
        printf "[AVAILABLE]\n"
        printf "Getting updated script... "
        # download updated script
        if ! wget --quiet --tries=3 --timeout=10 -O "update.sh.tmp" "${server}${repoScriptName}"; then
            errNotify
            # delete failed download as necessary
            rm -f ./update.sh.tmp 2>/dev/null
            errMsg "Unable to download script update. Try again later." 42
        else
            # verify download
            dlScriptChecksum=$(sha256sum "update.sh.tmp" | grep -o '^\S*')
            if ! [ "$dlScriptChecksum" = "$repoScriptChecksum" ]; then
                printf "[ERROR]\n"
                # delete corrupt download as necessary
                rm -f ./update.sh.tmp 2>/dev/null
                errMsg "Checksum mismatch! Try again later." 42
            else
                okNotify
                printf "\n%s*** This script has been updated. Please re-run it to load the updated version of this file. ***%s\n\n" "$warn" "$norm"
                # overwrite this script with updated script
                mv -f ./update.sh.tmp "$localScriptName"
            fi
        fi
    fi

    ## update files
    while IFS='  ' read -r field1 field2; do
        printf "\nChecking '%s' for updates... " "$field2"
        updateFilename="$field2"
        repoFileChecksum="$field1"
        if [ -f "$updateFilename" ]; then
            localFileChecksum=$(sha256sum "$updateFilename" | grep -o '^\S*')
        else
            localFileChecksum=0
        fi

        # update file if necessary
        if ! [ "$localFileChecksum" = "$repoFileChecksum" ]; then
            printf "[AVAILABLE]\n"
            updatesAvailable=$((updatesAvailable + 1))
            # download update
            printf "Downloading updated '%s'... " "$updateFilename"
            if ! wget --quiet --tries=3 --timeout=10 -O "$updateFilename.tmp" "${server}${updateFilename}"; then
                errNotify
                downloadFailed=$((downloadFailed + 1))
                # delete failed download file as necessary
                rm -f "$updateFilename.tmp" 2>&1
            else
                okNotify
                downloadSuccess=$((downloadSuccess + 1))
                # verify download
                printf "Verifying '%s'... " "$updateFilename"
                localFileChecksum=$(sha256sum "$updateFilename.tmp" | grep -o '^\S*')
                if ! [ "$localFileChecksum" = "$repoFileChecksum" ]; then
                    errNotify
                    updateFailed=$((updateFailed + 1))
                    # delete corrupted download file as necessary
                    rm -f "$updateFilename.tmp" 2>&1
                else
                    okNotify
                    updateSuccess=$((updateSuccess + 1))
                    # overwrite old version of file
                    mv -f "$updateFilename.tmp" "$updateFilename"
                fi
            fi
        else
            printf "[NONE]\n"
        fi
    done <"$checksumFilename"
fi

#
# display results
if [ "$doScriptUpdate" -eq 1 ]; then
    printf "\n%s*** Results ***%s\n" "$info" "$norm"
    printf "\tUpdates: %s available\n" "$updatesAvailable"
    printf "\tDownloads: %s%s successful%s, %s%s failed%s\n" "$ok" "$downloadSuccess" "$norm" "$err" "$downloadFailed" "$norm"
    printf "\tUpdates: %s%s applied%s, %s%s failed%s\n" "$ok" "$updateSuccess" "$norm" "$err" "$updateFailed" "$norm"
fi

#
# exit
if [ "$downloadFailed" -gt 0 ]; then
    exit 43
elif [ "$updateFailed" -gt 0 ]; then
    exit 44
else
    exit 0
fi
# this is a trap for mis-coding... should never get an exit code 99!
exit 99

#
# exit return codes
# 0:        normal exit, no errors
# 1:        missing or invalid parameter
# 2:        docker not found or no docker permissions
# 31:       unable to update docker container
# 4x:       helper files errors
#   41:     unable to download checksums
#   42:     update script: unable to download or bad checksum
#   43:     update helpers: unable to download
#   44:     update helpers: bad checksum, no update
# 99:       coding mistake trap -- this return code should never happen!

#EOF
