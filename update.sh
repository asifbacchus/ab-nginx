#!/bin/sh

### update script for ab-nginx container and utility scripts
# version 1.0.0
# script by Asif Bacchus
###

### functions
errMsg() {
  printf "\n%s%s%s\n\n" "$err" "$1" "$norm"
  exit 1
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

### text formatting presets
if command -v tput >/dev/null 2>&1; then
  err=$(tput bold)$(tput setaf 1)
  info=$(tput bold)$(tput setaf 6)
  norm=$(tput sgr0)
  ok=$(tput sgr0)$(tput setaf 2)
  warn=$(tput bold)$(tput setaf 3)
else
  err=''
  info=''
  norm=''
  ok=''
  warn=''
fi

### pre-requisites

# check if wget is installed
if ! command -v wget >/dev/null 2>&1; then
  errMsg "Sorry, this script requires that 'wget' is installed in order to download updates. Exiting."
fi

# check if docker is installed
if ! command -v docker >/dev/null 2>&1; then
  errMsg "Sorry, it appears that docker is not installed on this machine! Exiting."
fi

# is user root or in the docker group?
if [ ! "$(id -u)" -eq 0 ]; then
  if ! id -Gn | grep docker >/dev/null; then
    errMsg "You must either be root or in the 'docker' group to pull container updates."
  fi
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
containerUpdatePath="docker.asifbacchus.app/$dockerNamespace/$containerName:latest"
server="https://updates.asifbacchus.app/docker/$dockerNamespace/$containerName/"
checksumFilename='checksums.sha256'

# files to update
localScriptName="$(basename "$0")"
repoScriptName='update.sh'
updateFiles=""

### update container
printf "%s\n*** Updating %s container and service scripts ***\n\n%s" "$info" "$containerName" "$norm"

printf "Updating container:\n"
if ! docker pull "$containerUpdatePath"; then
  errMsg "There was an error updating the container. Try again later."
else
  okMsg "Container updated!"
fi

### update scripts
printf "%sUpdating %s service scripts%s\n" "$info" "$containerName" "$norm"

## download latest checksums
printf "Getting latest checksums... "
if ! wget --quiet --tries=3 --timeout=10 -N "${server}${checksumFilename}"; then
  errNotify
  errMsg "Unable to download checksums. Try again later."
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
    errMsg "Unable to download script update. Try again later."
  else
    # verify download
    dlScriptChecksum=$(sha256sum "update.sh.tmp" | grep -o '^\S*')
    if ! [ "$dlScriptChecksum" = "$repoScriptChecksum" ]; then
      printf "[ERROR]\n"
      # delete corrupt download as necessary
      rm -f ./update.sh.tmp 2>/dev/null
      errMsg "Checksum mismatch! Try again later."
    else
      okNotify
      printf "\n%s*** This script has been updated. Please re-run it to load the updated version of this file. ***%s\n\n" "$warn" "$norm"
      # overwrite this script with updated script
      mv -f ./update.sh.tmp "$localScriptName"
      exit 0
    fi
  fi
fi

## update files
set -- dummy $updateFiles
shift
for file; do
  updateTarget="$file"
  printf "\nChecking '%s' for updates... " "$updateTarget"
  repoFile=$(grep "$updateTarget" "$checksumFilename" | grep -o '^\S*')
  if [ -f "$file" ]; then
    localFile=$(sha256sum "$updateTarget" | grep -o '^\S*')
  else
    localFile=0
  fi

  if ! [ "$localFile" = "$repoFile" ]; then
    printf "[AVAILABLE]\n"
    updatesAvailable=$((updatesAvailable + 1))
    # download update
    printf "Downloading updated '%s'... " "$updateTarget"
    # specify a name here so that wget overwrites the file instead of just appending a number
    if ! wget --quiet --tries=3 --timeout=10 -O "$updateTarget" "${server}${updateTarget}"; then
      errNotify
      downloadFailed=$((downloadFailed + 1))
    else
      okNotify
      downloadSuccess=$((downloadSuccess + 1))
      # verify download
      printf "Verifying '%s'... " "$updateTarget"
      localFile=$(sha256sum "$updateTarget" | grep -o '^\S*')
      if ! [ "$localFile" = "$repoFile" ]; then
        errNotify
        updateFailed=$((updateFailed + 1))
      else
        okNotify
        updateSuccess=$((updateSuccess + 1))
      fi
    fi
  else
    printf "[NONE]\n"
  fi
done

### display results
printf "\n%sResults:%s\n" "$info" "$norm"
printf "\tUpdates: %s available\n" "$updatesAvailable"
printf "\tDownloads: %s%s successful%s, %s%s failed%s\n" "$ok" "$downloadSuccess" "$norm" "$err" "$downloadFailed" "$norm"
printf "\tUpdates: %s%s applied%s, %s%s failed%s\n" "$ok" "$updateSuccess" "$norm" "$err" "$updateFailed" "$norm"

exit 0