#!/usr/bin/env bash
set -eu -o pipefail

# Links to this file :
# https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/refs/heads/master/setup.sh
# https://tinyurl.com/38x8e73f
# https://urlr.me/8Nm2bZ
# use 'curl -L -o setup.sh $URL'
# or execute directly : 'bash <(curl -L -s $URL) $ARGS'
# See readme for more options

###########################################################################################
## Settings
###########################################################################################

SETUP_SCRIPT_LOCATION=$(readlink -f "${BASH_SOURCE}")
case $SETUP_SCRIPT_LOCATION in
    /dev*|/proc*) SETUP_SCRIPT_DIR=$(pwd) ;; # used as 'bash <(curl -L -s $URL)' without source folder: use pwd
    *) SETUP_SCRIPT_DIR=$(dirname "${SETUP_SCRIPT_LOCATION}") ;;
esac
TARGET_GIT_CLONE_FOLDER="${SETUP_SCRIPT_DIR}/linux_postinstall"

###########################################################################################
## Functions
###########################################################################################

function prefixprint() {
    local prefix="[$(date +"%Y-%m-%d.%T.%3N")] [LINUX_POSTINSTALL]"
    case $(echo "${1:-info}" | tr '[:upper:]' '[:lower:]') in
        debug)   echo "${prefix} DEBUG   ::" ;;
        info)    echo "${prefix} INFO    ::" ;;
        warning) echo "${prefix} WARNING ::" ;;
        error)   echo "${prefix} ERROR   ::" ;;
        *)       echo "${prefix} FATAL   :: Unkown logging level '$1'" 1>&2 
                 exit 1 ;;
    esac
}
echo "$(prefixprint info) Start."
###########################################################################################
## Checks
###########################################################################################

case $(whoami) in
    root) : ;;
    *) echo "$(prefixprint error) Must execute as root." ; exit 1 ;;
esac

###########################################################################################
## Logic
###########################################################################################

# 1. install minimal toolset (curl, git)
echo "$(prefixprint) Install minimal toolset"
. /etc/os-release
case ${ID} in
    ubuntu) apt udpate ; apt install curl git ; apt clean ;;
    debian) apt udpate ; apt install curl git ; apt clean ;;
    *) echo "$(prefixprint error) Unsupported distro '${ID}'" ; exit 1 ;;
esac

# 2. get latest repo
if [ ! -d ${TARGET_GIT_CLONE_FOLDER} ]; then
    echo "$(prefixprint) Cloning repository"
    git clone https://github.com/antoine-morvan/linux_postinstall.git ${TARGET_GIT_CLONE_FOLDER}
else
    echo "$(prefixprint) Target clone folder already present; reset to latest state"
    (cd ${TARGET_GIT_CLONE_FOLDER} && git checkout . && git reset --hard && git clean -xdff && git checkout master && git pull)
fi

# 2. run setup scripts
echo "$(prefixprint) Start setup"
echo "$(prefixprint error) TODO args = '$@'"

###########################################################################################
## Exit
###########################################################################################
echo "$(prefixprint) Done."
exit 0
