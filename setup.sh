#!/usr/bin/env bash
set -eu -o pipefail

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
## Settings
###########################################################################################
SETUP_SCRIPT_LOCATION=$(readlink -f "${BASH_SOURCE}")
SETUP_SCRIPT_DIR=$(dirname "${SETUP_SCRIPT_LOCATION}")
TARGET_GIT_CLONE_FOLDER="${SETUP_SCRIPT_DIR}/linux_postinstall"

###########################################################################################
## Checks
###########################################################################################
for CMD in git; do
    (command -v $CMD &> /dev/null) || (echo "$(prefixprint error) missing '$CMD' command" && exit 1)
done

###########################################################################################
## Logic
###########################################################################################

# 1. get latest repo
if [ ! -d ${TARGET_GIT_CLONE_FOLDER} ]; then
    echo "$(prefixprint) Cloning repository"
    git clone https://github.com/antoine-morvan/linux_postinstall.git ${TARGET_GIT_CLONE_FOLDER}
else
    echo "$(prefixprint) Target clone folder already present; reset to latest state"
    (cd ${TARGET_GIT_CLONE_FOLDER} && git checkout . && git reset --hard && git clean -xdff && git checkout master && git pull)
fi

# 2. run setup scripts
echo "$(prefixprint) Start setup"
echo "$(prefixprint error) TODO"

###########################################################################################
## Exit
###########################################################################################
echo "$(prefixprint) Done."
exit 0
